module Media
  class GenerateVideoThumbnailJob < ApplicationJob
    queue_as :media

    limits_concurrency(
      to: 1,
      key: ->(asset_id:, **) { MediaConstants::Processing.concurrency_key(asset_id) },
      duration: 30.minutes
    )

    retry_on MediaService::CompressionError, StorageService::Error,
             wait: :polynomially_longer, attempts: 3 do |job, error|
      job.send(:broadcast_retry_exhausted!, error)
    end
    discard_on ActiveRecord::RecordNotFound

    def perform(asset_id:, replace: false, notification_user_id: nil, operation_id: nil)
      asset = Asset.find(asset_id)
      @notification_user_id = notification_user_id.presence || asset.created_by_id.presence || asset.updated_by_id.presence
      @operation_id = operation_id.presence || "#{NotificationConstants::OperationType::VIDEO_THUMBNAIL}:#{asset.id}:#{job_id}"
      return unless asset.thumbnail_generatable?
      return if asset.thumbnail.present? && !replace

      previous_status = asset.status
      asset.mark_processing!
      broadcast_processing(asset)

      temp_dir = Dir.mktmpdir("video_thumbnail")
      input_path = File.join(temp_dir, "input.#{asset.extension.presence || 'mp4'}")
      output_path = File.join(temp_dir, "thumbnail.webp")
      StorageService::Client.download(asset.storage_key, input_path)
      MediaService::VideoThumbnailer.generate(input_path, output_path: output_path)
      result = StorageService::Client.upload(
        output_path,
        storage_key: AssetConstants::AssetName.thumbnail_for(asset, version: replace ? job_id : nil),
        resource_type: "image"
      )

      thumbnail = nil
      Asset.transaction do
        asset.thumbnail&.destroy!
        thumbnail = Asset.create!(
        name: result[:storage_key],
        url: result[:url],
        type: AssetConstants::AssetType::THUMBNAIL,
        format: AssetConstants::AssetFormat::IMAGE,
        extension: result[:format].presence || MediaConstants::IMAGE_EXT_WEBP,
        size_bytes: result[:bytes] || File.size(output_path),
        source: AssetConstants::AssetSource::UPLOAD,
        status: MediaConstants::Status::READY,
        storage_key: result[:storage_key],
        assetable: asset.assetable,
        parent_asset: asset,
        created_by_id: asset.created_by_id
        )
      end
      restore_status(asset, previous_status)
      broadcast(asset, thumbnail)
    rescue MediaService::CompressionError, StorageService::Error
      StorageService::Client.delete(result[:storage_key]) if result&.dig(:storage_key) && !thumbnail&.persisted?
      raise
    rescue StandardError
      StorageService::Client.delete(result[:storage_key]) if result&.dig(:storage_key) && !thumbnail&.persisted?
      broadcast_failure(asset) if asset
      raise
    ensure
      FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
    end

    private

    def restore_status(asset, previous_status)
      terminal_status = previous_status.in?([ MediaConstants::Status::READY, MediaConstants::Status::OPTIMAL ]) ? previous_status : MediaConstants::Status::READY
      asset.update!(status: terminal_status)
    end

    def broadcast_processing(asset)
      return if @notification_user_id.blank?

      NotificationService::Center.operation(
        user_id: @notification_user_id,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::VIDEO_THUMBNAIL,
        operation_status: NotificationConstants::OperationStatus::PROCESSING,
        message: MessageService::Admin::Asset.t(MessageService::Admin::Asset::THUMBNAIL_GENERATING, name: asset.name),
        link: "/admin/assets/#{asset.id}",
        data: {
          type: MediaConstants::SocketEvent::ASSET_THUMBNAIL_PROCESSING,
          asset_id: asset.id,
          status: MediaConstants::Status::PROCESSING
        }
      )
    rescue StandardError => e
      Rails.logger.error("[GenerateVideoThumbnailJob] Processing broadcast error: #{e.message}")
    end

    def broadcast_retry_exhausted!(_error)
      arguments = self.arguments.first.with_indifferent_access
      asset = Asset.find_by(id: arguments[:asset_id])
      return unless asset

      @notification_user_id = arguments[:notification_user_id].presence || asset.created_by_id.presence || asset.updated_by_id.presence
      @operation_id = arguments[:operation_id].presence || "#{NotificationConstants::OperationType::VIDEO_THUMBNAIL}:#{asset.id}:#{job_id}"
      broadcast_failure(asset)
    end

    def broadcast(asset, thumbnail)
      return if @notification_user_id.blank?

      message = MessageService::Admin::Asset.t(
        MessageService::Admin::Asset::THUMBNAIL_GENERATED,
        name: asset.display_name
      )
      NotificationService::Center.operation(
        user_id: @notification_user_id,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::VIDEO_THUMBNAIL,
        operation_status: NotificationConstants::OperationStatus::COMPLETED,
        message: message,
        link: "/admin/assets/#{asset.id}",
        data: {
          type: MediaConstants::SocketEvent::ASSET_THUMBNAIL_GENERATED,
          asset_id: asset.id,
          thumbnail: AssetSerializer.new(thumbnail).serializable_hash[:data][:attributes]
        }
      )
    rescue StandardError => e
      Rails.logger.error("[GenerateVideoThumbnailJob] Broadcast error: #{e.message}")
    end

    def broadcast_failure(asset)
      asset.mark_failed! unless asset.failed?
      return if @notification_user_id.blank?

      message = MessageService::Admin::Asset.t(MessageService::Admin::Asset::THUMBNAIL_FAILED, name: asset.display_name)
      NotificationService::Center.operation(
        user_id: @notification_user_id,
        operation_id: @operation_id,
        operation_type: NotificationConstants::OperationType::VIDEO_THUMBNAIL,
        operation_status: NotificationConstants::OperationStatus::FAILED,
        message: message,
        link: "/admin/assets/#{asset.id}",
        data: {
          type: MediaConstants::SocketEvent::ASSET_THUMBNAIL_FAILED,
          asset_id: asset.id
        }
      )
    rescue StandardError => e
      Rails.logger.error("[GenerateVideoThumbnailJob] Failure broadcast error: #{e.message}")
    end
  end
end
