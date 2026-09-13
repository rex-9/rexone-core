module Media
  class ConvertImageJob < ApplicationJob
    queue_as :media

    limits_concurrency(
      to: 1,
      key: ->(asset_id:, **) { MediaConstants::Processing.concurrency_key(asset_id) },
      duration: 30.minutes
    )

    retry_on MediaService::ConversionError, StorageService::Error,
             wait: :polynomially_longer, attempts: 3 do |job, error|
      job.send(:mark_retry_exhausted!, error)
    end
    discard_on ActiveRecord::RecordNotFound

    def perform(asset_id:, notification_user_id: nil, operation_id: nil)
      @asset = Asset.find(asset_id)
      return unless @asset.extension == MediaConstants::IMAGE_EXT_SVG

      @notification_user_id = notification_user_id.presence || @asset.created_by_id.presence || @asset.updated_by_id.presence
      @operation_id = operation_id.presence || "#{NotificationConstants::OperationType::ASSET_COMPRESSION}:#{@asset.id}:#{job_id}"

      @asset.mark_processing!
      broadcast_status_change(MediaConstants::Status::PROCESSING)
      input_path = download_from_storage
      output_path = MediaService::ImageConversion.encode_png(input_path)
      upload_converted(output_path)
      persist_conversion(output_path)
      enqueue_image_compression
    rescue MediaService::ConversionError, StorageService::Error
      raise
    rescue StandardError => error
      mark_failed!(error)
      raise
    ensure
      FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
    end

    private

    def download_from_storage
      @temp_dir = Dir.mktmpdir("image_conversion")
      input_path = File.join(@temp_dir, "input.svg")
      StorageService::Client.download(@asset.storage_key, input_path)
      input_path
    end

    def upload_converted(output_path)
      @previous_storage_key = @asset.storage_key
      @converted_storage_key = AssetConstants::AssetName.with_extension(
        @asset.storage_key,
        MediaConstants::IMAGE_EXT_PNG
      )
      @upload_result = StorageService::Client.upload(
        output_path,
        storage_key: @converted_storage_key,
        folder: File.dirname(@converted_storage_key),
        resource_type: "image",
        overwrite: true
      )
    end

    def persist_conversion(output_path)
      @asset.update!(
        storage_key: @upload_result[:storage_key],
        name: @upload_result[:storage_key],
        url: @upload_result[:url],
        extension: MediaConstants::IMAGE_EXT_PNG,
        format: AssetConstants::AssetFormat::IMAGE,
        size_bytes: @upload_result[:bytes] || File.size(output_path),
        status: MediaConstants::Status::PENDING
      )
      delete_previous_object
    rescue StandardError
      StorageService::Client.delete(@upload_result[:storage_key], resource_type: "image") if @upload_result&.dig(:storage_key)
      raise
    end

    def enqueue_image_compression
      Media::CompressImageJob.perform_later(
        asset_id: @asset.id,
        notification_user_id: @notification_user_id,
        operation_id: @operation_id
      )
      Rails.logger.info("[ConvertImageJob] Enqueued PNG compression for converted asset #{@asset.id}")
    end

    def delete_previous_object
      return if @previous_storage_key == @asset.storage_key

      StorageService::Client.delete(@previous_storage_key, resource_type: "image")
    rescue StorageService::Error => error
      Rails.error.report(error)
      Rails.logger.error("[ConvertImageJob] Failed to delete replaced object #{@previous_storage_key}: #{error.message}")
    end

    def mark_retry_exhausted!(error)
      job_arguments = arguments.first.with_indifferent_access
      @asset = Asset.find_by(id: job_arguments[:asset_id])
      @notification_user_id = job_arguments[:notification_user_id].presence || @asset&.created_by_id.presence || @asset&.updated_by_id.presence
      @operation_id = job_arguments[:operation_id].presence || "#{NotificationConstants::OperationType::ASSET_COMPRESSION}:#{@asset&.id}:#{job_id}"
      mark_failed!(error) if @asset
    end

    def mark_failed!(error)
      @asset.mark_failed!
      broadcast_status_change(MediaConstants::Status::FAILED)
      Rails.error.report(error)
      Rails.logger.error("[ConvertImageJob] Conversion failed for asset #{@asset.id}: #{error.message}")
    end

    def broadcast_status_change(status)
      return if @notification_user_id.blank?

      event_type = if status == MediaConstants::Status::FAILED
        MediaConstants::SocketEvent::ASSET_COMPRESSION_FAILED
      elsif status == MediaConstants::Status::PROCESSING
        MediaConstants::SocketEvent::ASSET_COMPRESSING
      else
        MediaConstants::SocketEvent::ASSET_COMPRESSED
      end
      message_key = if status == MediaConstants::Status::FAILED
        MessageService::Admin::Asset::COMPRESSION_FAILED
      elsif status == MediaConstants::Status::PROCESSING
        MessageService::Admin::Asset::COMPRESSION_IN_PROGRESS
      else
        MessageService::Admin::Asset::COMPRESSION_OPTIMAL
      end
      operation_status = if status == MediaConstants::Status::FAILED
        NotificationConstants::OperationStatus::FAILED
      elsif status == MediaConstants::Status::PROCESSING
        NotificationConstants::OperationStatus::PROCESSING
      else
        NotificationConstants::OperationStatus::COMPLETED
      end

      NotificationService::Center.operation(
        user_id: @notification_user_id,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::ASSET_COMPRESSION,
        operation_status: operation_status,
        message: MessageService::Admin::Asset.t(message_key, name: @asset.name),
        link: "/admin/assets/#{@asset.id}",
        data: {
          type: event_type,
          asset_id: @asset.id,
          status: status,
          size_bytes: @asset.size_bytes,
          url: @asset.url
        }
      )
    rescue StandardError => error
      Rails.error.report(error)
      Rails.logger.error("[ConvertImageJob] Broadcast failed for asset #{@asset.id}: #{error.message}")
    end
  end
end
