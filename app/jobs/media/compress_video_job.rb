# app/jobs/media/compress_video_job.rb

module Media
  class CompressVideoJob < ApplicationJob
    queue_as :media

    limits_concurrency(
      to: 1,
      key: ->(asset_id:, **) { MediaConstants::Processing.concurrency_key(asset_id) },
      duration: 30.minutes
    )

    retry_on MediaService::CompressionError, StorageService::Error,
             wait: :polynomially_longer, attempts: 3 do |job, error|
      job.send(:mark_retry_exhausted!, error)
    end
    discard_on ActiveRecord::RecordNotFound

    def perform(asset_id:, notification_user_id: nil, operation_id: nil)
      @asset = Asset.find(asset_id)
      @notification_user_id = notification_user_id.presence || @asset.created_by_id.presence || @asset.updated_by_id.presence
      @operation_id = operation_id.presence || "#{NotificationConstants::OperationType::ASSET_COMPRESSION}:#{@asset.id}:#{job_id}"
      return if @asset.optimal? || @asset.max_compressed?

      @asset.mark_processing!
      broadcast_status_change(MediaConstants::Status::PROCESSING)

      input_path = download_from_storage
      original_bytes = File.size(input_path)
      compressed_path = MediaService::VideoCompressor.compress(input_path)
      compressed_bytes = File.size(compressed_path)

      if compressed_bytes >= original_bytes
        # Compressed file is not smaller — original file is already optimal!
        Rails.logger.info("[CompressVideoJob] Original (#{original_bytes} bytes) already optimal (compressed: #{compressed_bytes} bytes). Marking optimal immediately.")
        @asset.mark_optimal!
        broadcast_status_change(MediaConstants::Status::OPTIMAL)
        return
      end

      reduction_ratio = (original_bytes - compressed_bytes).to_f / original_bytes
      reupload_compressed(compressed_path)
      finalize_asset(compressed_path)
      Rails.logger.info("[CompressVideoJob] Compressed #{original_bytes} -> #{compressed_bytes} bytes for asset #{asset_id} (#{(reduction_ratio * 100).round(1)}% reduction)")

      # If reduction is negligible (below threshold), mark optimal immediately — no cache needed
      if reduction_ratio < MediaConstants::MIN_REDUCTION_THRESHOLD
        Rails.logger.info("[CompressVideoJob] Asset #{asset_id} reduction (#{(reduction_ratio * 100).round(1)}%) below threshold. Marking optimal immediately.")
        @asset.mark_optimal!
        broadcast_status_change(MediaConstants::Status::OPTIMAL)
        return
      end

      # Meaningful reduction achieved — check pass count fallback
      count = @asset.increment_compression_count!

      if count >= MediaConstants::MAX_COMPRESSION_PASSES
        @asset.mark_optimal!
        broadcast_status_change(MediaConstants::Status::OPTIMAL)
      else
        @asset.mark_ready!
        broadcast_status_change(MediaConstants::Status::READY)
      end

      Rails.logger.info("[CompressVideoJob] Completed for asset #{asset_id} (pass #{count}/#{MediaConstants::MAX_COMPRESSION_PASSES})")
    rescue MediaService::CompressionError, StorageService::Error => e
      Rails.logger.warn("[CompressVideoJob] Retriable failure for asset #{asset_id}: #{e.message}")
      raise
    rescue StandardError => e
      mark_failed!(e)
      raise
    ensure
      cleanup_temp_files
    end

    private

    def mark_retry_exhausted!(error)
      arguments = self.arguments.first.with_indifferent_access
      @asset = Asset.find_by(id: arguments[:asset_id])
      return unless @asset

      @notification_user_id = arguments[:notification_user_id].presence || @asset.created_by_id.presence || @asset.updated_by_id.presence
      @operation_id = arguments[:operation_id].presence || "#{NotificationConstants::OperationType::ASSET_COMPRESSION}:#{@asset.id}:#{job_id}"
      mark_failed!(error)
    end

    def mark_failed!(error)
      @asset&.mark_failed! if @asset&.persisted?
      broadcast_status_change(MediaConstants::Status::FAILED)
      Rails.logger.error("[CompressVideoJob] Failed for asset #{@asset&.id}: #{error.message}")
    end

    def broadcast_status_change(status)
      return unless @asset

      event_type = case status
      when MediaConstants::Status::READY, MediaConstants::Status::OPTIMAL
                     MediaConstants::SocketEvent::ASSET_COMPRESSED
      when MediaConstants::Status::FAILED
                     MediaConstants::SocketEvent::ASSET_COMPRESSION_FAILED
      else
                     MediaConstants::SocketEvent::ASSET_COMPRESSING
      end

      payload = {
        type: event_type,
        asset_id: @asset.id,
        status: status,
        size_bytes: @asset.size_bytes,
        url: @asset.url
      }

      msg = case status
      when MediaConstants::Status::READY
              MessageService::Admin::Asset.t(MessageService::Admin::Asset::COMPRESSION_COMPLETED, name: @asset.name)
      when MediaConstants::Status::OPTIMAL
              MessageService::Admin::Asset.t(MessageService::Admin::Asset::COMPRESSION_OPTIMAL, name: @asset.name)
      when MediaConstants::Status::FAILED
              MessageService::Admin::Asset.t(MessageService::Admin::Asset::COMPRESSION_FAILED, name: @asset.name)
      else
              MessageService::Admin::Asset.t(MessageService::Admin::Asset::COMPRESSION_IN_PROGRESS, name: @asset.name)
      end

      return if @notification_user_id.blank?

      NotificationService::Center.operation(
        user_id: @notification_user_id,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::ASSET_COMPRESSION,
        operation_status: operation_status(status),
        message: msg,
        link: "/admin/assets/#{@asset.id}",
        data: payload
      )
    rescue => e
      Rails.logger.error("[CompressVideoJob] Broadcast error for asset #{@asset.id}: #{e.message}")
    end

    def operation_status(status)
      return NotificationConstants::OperationStatus::FAILED if status == MediaConstants::Status::FAILED
      return NotificationConstants::OperationStatus::PROCESSING if status == MediaConstants::Status::PROCESSING

      NotificationConstants::OperationStatus::COMPLETED
    end

    def download_from_storage
      require "tempfile"

      ext = @asset.extension.present? ? ".#{@asset.extension}" : ".mp4"
      @temp_dir = Dir.mktmpdir("media_compress")
      input_path = File.join(@temp_dir, "input#{ext}")

      StorageService::Client.download(@asset.storage_key, input_path)

      Rails.logger.info("[CompressVideoJob] Downloaded #{File.size(input_path)} bytes to #{input_path}")
      input_path
    end

    def reupload_compressed(compressed_path)
      result = StorageService::Client.upload(
        compressed_path,
        storage_key: @asset.storage_key,
        folder: File.dirname(@asset.storage_key.to_s).presence || "admin_uploads/video",
        resource_type: AssetConstants::AssetFormat.storage_resource_type(@asset.extension),
        overwrite: true
      )

      @upload_result = result
    end

    def finalize_asset(compressed_path)
      @asset.update!(
        url: @upload_result[:url],
        size_bytes: @upload_result[:bytes] || File.size(compressed_path),
        status: MediaConstants::Status::READY
      )
    end

    def cleanup_temp_files
      FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
    end
  end
end
