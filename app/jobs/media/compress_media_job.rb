module Media
  class CompressMediaJob < ApplicationJob
    LOG_PREFIX = "[CompressMediaJob]".freeze
    OPERATION_COMPRESS = "compress".freeze

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

    def perform(asset_id:, operation: OPERATION_COMPRESS, notification_user_id: nil, operation_id: nil)
      @asset = Asset.find(asset_id)
      @operation = operation
      @notification_user_id = notification_user_id.presence || @asset.created_by_id.presence || @asset.updated_by_id.presence
      @operation_id = operation_id.presence || "#{NotificationConstants::OperationType::ASSET_COMPRESSION}:#{@asset.id}:#{job_id}"

      case operation
      when OPERATION_COMPRESS
        compress_asset
      else
        raise ArgumentError, "Unsupported media operation: #{operation}"
      end
    rescue MediaService::CompressionError, StorageService::Error => e
      Rails.logger.warn("#{LOG_PREFIX} Retriable failure for asset #{asset_id}: #{e.message}")
      raise
    rescue StandardError => e
      mark_failed!(e)
      raise
    ensure
      cleanup_temp_files
    end

    private

    def compress_asset
      return if @asset.optimal? || @asset.max_compressed?
      return unless @asset.compressible?

      @asset.mark_processing!
      broadcast_status_change(MediaConstants::Status::PROCESSING)

      input_path = download_from_storage
      original_bytes = File.size(input_path)
      compressed_path = compressor.compress(input_path)
      compressed_bytes = File.size(compressed_path)

      if compressed_bytes >= original_bytes
        Rails.logger.info("#{LOG_PREFIX} Original (#{original_bytes} bytes) already optimal (compressed: #{compressed_bytes} bytes). Marking optimal immediately.")
        @asset.mark_optimal!
        broadcast_status_change(MediaConstants::Status::OPTIMAL)
        return
      end

      reduction_ratio = (original_bytes - compressed_bytes).to_f / original_bytes
      reupload_compressed(compressed_path)
      finalize_asset(compressed_path)
      Rails.logger.info("#{LOG_PREFIX} Compressed #{original_bytes} -> #{compressed_bytes} bytes for asset #{@asset.id} (#{(reduction_ratio * 100).round(1)}% reduction)")

      if reduction_ratio < MediaConstants::MIN_REDUCTION_THRESHOLD
        Rails.logger.info("#{LOG_PREFIX} Asset #{@asset.id} reduction (#{(reduction_ratio * 100).round(1)}%) below threshold. Marking optimal immediately.")
        @asset.mark_optimal!
        broadcast_status_change(MediaConstants::Status::OPTIMAL)
        return
      end

      count = @asset.increment_compression_count!
      if count >= MediaConstants::MAX_COMPRESSION_PASSES
        @asset.mark_optimal!
        broadcast_status_change(MediaConstants::Status::OPTIMAL)
      else
        @asset.mark_ready!
        broadcast_status_change(MediaConstants::Status::READY)
      end

      Rails.logger.info("#{LOG_PREFIX} Completed for asset #{@asset.id} (pass #{count}/#{MediaConstants::MAX_COMPRESSION_PASSES})")
    end

    def compressor
      case @asset.format
      when AssetConstants::AssetFormat::IMAGE then MediaService::ImageCompressor
      when AssetConstants::AssetFormat::AUDIO then MediaService::AudioCompressor
      when AssetConstants::AssetFormat::VIDEO then MediaService::VideoCompressor
      else
        raise MediaService::CompressionError, "Unsupported asset format: #{@asset.format}"
      end
    end

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
      Rails.logger.error("#{LOG_PREFIX} Failed for asset #{@asset&.id}: #{error.message}")
    end

    def broadcast_status_change(status)
      return unless @asset

      NotificationService::Center.operation(
        user_id: @notification_user_id,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::ASSET_COMPRESSION,
        operation_status: operation_status(status),
        message: MessageService::Admin::Asset.t(message_key(status), name: @asset.name),
        link: "/admin/assets/#{@asset.id}",
        data: {
          type: socket_event_type(status),
          asset_id: @asset.id,
          status: status,
          size_bytes: @asset.size_bytes,
          url: @asset.url
        }
      ) if @notification_user_id.present?
    rescue => e
      Rails.logger.error("#{LOG_PREFIX} Broadcast error for asset #{@asset.id}: #{e.message}")
    end

    def socket_event_type(status)
      case status
      when MediaConstants::Status::READY, MediaConstants::Status::OPTIMAL
        MediaConstants::SocketEvent::ASSET_COMPRESSED
      when MediaConstants::Status::FAILED
        MediaConstants::SocketEvent::ASSET_COMPRESSION_FAILED
      else
        MediaConstants::SocketEvent::ASSET_COMPRESSING
      end
    end

    def message_key(status)
      case status
      when MediaConstants::Status::READY
        MessageService::Admin::Asset::COMPRESSION_COMPLETED
      when MediaConstants::Status::OPTIMAL
        MessageService::Admin::Asset::COMPRESSION_OPTIMAL
      when MediaConstants::Status::FAILED
        MessageService::Admin::Asset::COMPRESSION_FAILED
      else
        MessageService::Admin::Asset::COMPRESSION_IN_PROGRESS
      end
    end

    def operation_status(status)
      return NotificationConstants::OperationStatus::FAILED if status == MediaConstants::Status::FAILED
      return NotificationConstants::OperationStatus::PROCESSING if status == MediaConstants::Status::PROCESSING

      NotificationConstants::OperationStatus::COMPLETED
    end

    def download_from_storage
      ext = @asset.extension.present? ? ".#{@asset.extension}" : ".#{fallback_extension}"
      @temp_dir = Dir.mktmpdir("media_process")
      input_path = File.join(@temp_dir, "input#{ext}")
      StorageService::Client.download(@asset.storage_key, input_path)
      Rails.logger.info("#{LOG_PREFIX} Downloaded #{File.size(input_path)} bytes to #{input_path}")
      input_path
    end

    def fallback_extension
      case @asset.format
      when AssetConstants::AssetFormat::IMAGE then "jpg"
      when AssetConstants::AssetFormat::AUDIO then "m4a"
      when AssetConstants::AssetFormat::VIDEO then "mp4"
      else "bin"
      end
    end

    def reupload_compressed(compressed_path)
      output_extension = File.extname(compressed_path).delete(".").downcase
      @previous_storage_key = @asset.storage_key
      storage_key = if output_extension.present? && output_extension != @asset.extension
        AssetConstants::AssetName.with_extension(@asset.storage_key, output_extension)
      else
        @asset.storage_key
      end

      @upload_result = StorageService::Client.upload(
        compressed_path,
        storage_key: storage_key,
        folder: File.dirname(storage_key.to_s).presence || "admin_uploads/#{@asset.format}",
        resource_type: AssetConstants::AssetFormat.storage_resource_type(output_extension.presence || @asset.extension),
        overwrite: true
      )
    end

    def finalize_asset(compressed_path)
      out_ext = File.extname(compressed_path).delete(".").downcase.presence
      attrs = {
        storage_key: @upload_result[:storage_key],
        name: @upload_result[:storage_key],
        url: @upload_result[:url],
        size_bytes: @upload_result[:bytes] || File.size(compressed_path),
        status: MediaConstants::Status::READY
      }

      if out_ext.present? && out_ext != @asset.extension
        attrs[:extension] = out_ext
        attrs[:format] = AssetConstants::AssetFormat.from_extension(out_ext) || @asset.format
      end

      @asset.update!(attrs)
      delete_previous_object
    rescue StandardError
      delete_uploaded_replacement(out_ext)
      raise
    end
    def delete_uploaded_replacement(out_ext)
      return if @upload_result.blank? || @upload_result[:storage_key].blank? || @upload_result[:storage_key] == @previous_storage_key

      StorageService::Client.delete(
        @upload_result[:storage_key],
        resource_type: AssetConstants::AssetFormat.storage_resource_type(out_ext)
      )
    end

    def delete_previous_object
      return if @previous_storage_key.blank? || @previous_storage_key == @asset.storage_key

      StorageService::Client.delete(
        @previous_storage_key,
        resource_type: AssetConstants::AssetFormat.storage_resource_type(File.extname(@previous_storage_key).delete("."))
      )
    rescue StorageService::Error => e
      Rails.error.report(e)
      Rails.logger.error("#{LOG_PREFIX} Failed to delete replaced object #{@previous_storage_key}: #{e.message}")
    end

    def cleanup_temp_files
      FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
    end
  end
end
