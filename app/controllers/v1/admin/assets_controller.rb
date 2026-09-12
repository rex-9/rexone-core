# app/controllers/v1/admin/assets_controller.rb

class V1::Admin::AssetsController < V1::ApplicationController
  before_action :super_admin_required!, only: :read_storage_stats
  before_action :set_active_asset, only: %i[show update discard update_compress read_download update_thumbnail_regenerate update_thumbnail_upload update_subtitle_upload]
  before_action :set_asset_including_discarded, only: %i[undiscard destroy]

  # GET /v1/admin/assets
  def index
    discarded = params[:discarded].to_s == "true"
    scope = discarded ? Asset.with_discarded.discarded : Asset.kept
    assets = search_assets(scope)
    assets = filter_assets(assets)
    assets = if discarded
      sort(assets, columns: SortConstants::Columns::ASSET, default_column: "discarded_at")
    else
      sort(assets, columns: SortConstants::Columns::ASSET)
    end
    pagy, records = pagy(:offset, assets, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: admin_asset_message(
        discarded ? MessageService::Admin::Asset::DISCARDED_ASSETS_RETRIEVED : MessageService::Admin::Asset::ASSETS_RETRIEVED
      ),
      data: AssetSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/assets/:id
  def show
    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::ASSET_RETRIEVED),
      data: {
        asset: AssetSerializer.new(@asset).serializable_hash[:data][:attributes]
      }
    )
  end

  # POST /v1/admin/assets/upload
  def create_upload
    file = params[:file]

    if file.blank?
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::NO_FILE_UPLOADED),
        error: admin_asset_message(MessageService::Admin::Asset::FILE_REQUIRED)
      )
      return
    end

    max_size_mb = if determine_resource_type(file) == "video"
                    MediaConstants::MAX_VIDEO_SIZE_MB
    else
                    MediaConstants::MAX_NON_VIDEO_SIZE_MB
    end

    if file.size > max_size_mb.megabytes
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::SAVE_FAILED),
        error: admin_asset_message(
          MessageService::Admin::Asset::FILE_SIZE_EXCEEDED,
          limit: max_size_mb
        )
      )
      return
    end

    asset_type = params[:type].presence || AssetConstants::AssetType::GENERAL
    assetable_type = params[:assetable_type].presence
    assetable_id = params[:assetable_id].presence
    duration_secs = params[:duration_secs]

    conversion = nil
    begin
      conversion = MediaService::SvgToPng.prepare(file)
      storage_key = AssetConstants::AssetName.for_admin(type: asset_type, original_filename: conversion.filename)

      result = StorageService::Client.upload(
        conversion.file,
        storage_key: storage_key,
        resource_type: determine_resource_type(conversion.filename),
        metadata: {
          user_id: current_user.id.to_s,
          original_filename: file.original_filename
        }
      )

      asset = Asset.find_or_initialize_by(storage_key: result[:storage_key])
      asset.assign_attributes(
        name: result[:storage_key],
        url: result[:url],
        type: asset_type,
        format: determine_asset_format(conversion.filename),
        size_bytes: result[:bytes],
        duration_secs: duration_secs,
        source: AssetConstants::AssetSource::UPLOAD,
        assetable_type: assetable_type,
        assetable_id: assetable_id,
        storage_key: result[:storage_key],
        extension: result[:format] || File.extname(conversion.filename).delete("."),
        status: conversion.converted? ? MediaConstants::Status::OPTIMAL : compression_status_for(conversion.filename)
      )

      if asset.save
        enqueue_compression_if_needed(asset)

        render_json_response(
          status_code: 201,
          message: admin_asset_message(MessageService::Admin::Asset::ASSET_UPLOADED),
          data: {
            asset: AssetSerializer.new(asset).serializable_hash[:data][:attributes],
            storage_details: {
              storage_key: result[:storage_key],
              bytes: result[:bytes],
              format: result[:format]
            }
          }
        )
      else
        StorageService::Client.delete(
          result[:storage_key],
          resource_type: result[:resource_type]
        )

        render_json_response(
          status_code: 422,
          message: admin_asset_message(MessageService::Admin::Asset::SAVE_FAILED),
          error: asset.errors.full_messages.to_sentence
        )
      end
    rescue MediaService::ConversionError => e
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::SAVE_FAILED),
        error: e.message
      )
    rescue StorageService::Error => e
      render_json_response(
        status_code: 500,
        message: admin_asset_message(MessageService::Admin::Asset::STORAGE_UPLOAD_FAILED),
        error: e.message
      )
    ensure
      MediaService::SvgToPng.cleanup(conversion)
    end
  end

  # PUT /v1/admin/assets/:id
  def update
    new_type = params.dig(:asset, :type).presence
    client_name = params.dig(:asset, :name).to_s.strip
    old_storage_key = @asset.storage_key
    old_name = @asset.name
    new_storage_key = nil

    if new_type.present? && new_type != @asset.type && @asset.uploaded_file? && @asset.storage_key.present?
      new_storage_key = AssetConstants::AssetName.rename_type(@asset.storage_key, new_type, @asset.created_by_id)
      if new_storage_key != @asset.storage_key
        Rails.logger.info("[AssetsController] Renaming storage object: #{@asset.storage_key} -> #{new_storage_key}")
        StorageService::Client.move(@asset.storage_key, new_storage_key)
        @asset.storage_key = new_storage_key
        @asset.url = StorageService::Client.url(new_storage_key)
        @asset.name = new_storage_key
      end
    end

    update_params = admin_asset_params
    if new_storage_key.present?
      if client_name.blank? ||
         client_name == old_name ||
         client_name == old_storage_key ||
         client_name == new_storage_key ||
         client_name == AssetConstants::AssetName.rename_type(old_name, new_type, @asset.created_by_id)
        update_params = update_params.merge(name: new_storage_key)
      else
        update_params = update_params.merge(name: AssetConstants::AssetName.rename_type(client_name, new_type, @asset.created_by_id))
      end
    elsif new_type.present? && new_type == @asset.type && @asset.storage_key.present?
      expected_name = AssetConstants::AssetName.rename_type(client_name, @asset.type, @asset.created_by_id)
      if expected_name != client_name
        update_params = update_params.merge(name: expected_name)
      elsif @asset.name != @asset.storage_key && (@asset.name == old_storage_key || client_name == old_name)
        update_params = update_params.merge(name: @asset.storage_key)
      end
    end

    if @asset.update(update_params)
      render_json_response(
        status_code: 200,
        message: admin_asset_message(MessageService::Admin::Asset::ASSET_UPDATED),
        data: {
          asset: AssetSerializer.new(@asset).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::UPDATE_FAILED),
        error: @asset.errors.full_messages.to_sentence
      )
    end
  rescue StorageService::Error => e
    Rails.logger.error("[AssetsController] Failed to rename storage object: #{e.message}")
    render_json_response(
      status_code: 500,
      message: admin_asset_message(MessageService::Admin::Asset::UPDATE_FAILED),
      error: e.message
    )
  end

  # POST /v1/admin/assets/:id/discard
  def discard
    @asset.discard!

    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::ASSET_DISCARDED),
      data: {
        asset: AssetSerializer.new(@asset).serializable_hash[:data][:attributes]
      }
    )
  end

  # POST /v1/admin/assets/:id/undiscard
  def undiscard
    @asset.undiscard!

    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::ASSET_RESTORED),
      data: {
        asset: AssetSerializer.new(@asset).serializable_hash[:data][:attributes]
      }
    )
  end

  # GET /v1/admin/assets/storage_stats
  def read_storage_stats
    stats = StorageService::Client.storage_stats
    db_count = Asset.kept.count
    db_bytes = Asset.kept.sum(:size_bytes)

    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::STORAGE_STATS_RETRIEVED),
      data: {
        stats: stats.merge(
          db_assets_count: db_count,
          db_assets_bytes: db_bytes
        )
      }
    )
  end

  # DELETE /v1/admin/assets/:id
  def destroy
    @asset.destroy!

    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::ASSET_DELETED)
    )
  rescue ActiveRecord::RecordNotDestroyed => e
    render_json_response(
      status_code: 422,
      message: admin_asset_message(MessageService::Admin::Asset::ASSET_DELETED),
      error: e.message
    )
  end

  # DELETE /v1/admin/assets/bin
  def destroy_bin
    scope = Asset.with_discarded.discarded
    count = scope.count
    Asset.purge_and_destroy_all!(scope)

    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::RECYCLE_BIN_EMPTIED, count: count),
      data: { count: count }
    )
  end

  # POST /v1/admin/assets/discard_batch
  def discard_batch
    ids = Array(params[:ids]).compact_blank
    if ids.blank?
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::NO_ASSETS_SELECTED),
        error: admin_asset_message(MessageService::Admin::Asset::NO_ASSETS_SELECTED)
      )
      return
    end

    scope = Asset.kept.where(id: ids)
    count = 0
    scope.find_each do |asset|
      count += 1 if asset.discard
    end

    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::BATCH_DISCARDED, count: count),
      data: { count: count }
    )
  end

  # POST /v1/admin/assets/undiscard_batch
  def undiscard_batch
    ids = Array(params[:ids]).compact_blank
    if ids.blank?
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::NO_ASSETS_SELECTED),
        error: admin_asset_message(MessageService::Admin::Asset::NO_ASSETS_SELECTED)
      )
      return
    end

    scope = Asset.with_discarded.discarded.where(id: ids)
    count = 0
    scope.find_each do |asset|
      count += 1 if asset.undiscard
    end

    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::BATCH_RESTORED, count: count),
      data: { count: count }
    )
  end

  # POST /v1/admin/assets/destroy_batch
  def destroy_batch
    ids = Array(params[:ids]).compact_blank
    if ids.blank?
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::NO_ASSETS_SELECTED),
        error: admin_asset_message(MessageService::Admin::Asset::NO_ASSETS_SELECTED)
      )
      return
    end

    scope = Asset.with_discarded.where(id: ids)
    count = scope.count
    Asset.purge_and_destroy_all!(scope)

    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::BATCH_DELETED, count: count),
      data: { count: count }
    )
  end

  # POST /v1/admin/assets/:id/compress
  # Admin manually triggers compression for an asset.
  # Useful for retrying failed compressions or compressing assets uploaded before media was enabled.
  def update_compress
    if @asset.optimal? || @asset.max_compressed?
      @asset.mark_optimal! unless @asset.optimal?
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::COMPRESSION_ALREADY_OPTIMAL),
        error: admin_asset_message(MessageService::Admin::Asset::COMPRESSION_ALREADY_OPTIMAL),
        data: {
          asset: AssetSerializer.new(@asset.reload).serializable_hash[:data][:attributes]
        }
      )
      return
    end

    if @asset.pending? || @asset.processing?
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::COMPRESSION_IN_PROGRESS),
        error: admin_asset_message(MessageService::Admin::Asset::COMPRESSION_IN_PROGRESS)
      )
      return
    end

    unless @asset.compressible?
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::COMPRESSION_NOT_SUPPORTED),
        error: admin_asset_message(MessageService::Admin::Asset::COMPRESSION_NOT_SUPPORTED)
      )
      return
    end

    @asset.update!(status: MediaConstants::Status::PENDING)
    operation_id = "#{NotificationConstants::OperationType::ASSET_COMPRESSION}:#{@asset.id}:#{SecureRandom.uuid}"

    if @asset.compressible_video?
      Media::CompressVideoJob.perform_later(
        asset_id: @asset.id,
        notification_user_id: current_user.id,
        operation_id: operation_id
      )
    elsif @asset.compressible_image?
      Media::CompressImageJob.perform_later(asset_id: @asset.id, notification_user_id: current_user.id, operation_id: operation_id)
    elsif @asset.compressible_audio?
      Media::CompressAudioJob.perform_later(asset_id: @asset.id, notification_user_id: current_user.id, operation_id: operation_id)
    end

    NotificationService::Center.operation(
      user_id: current_user.id,
      operation_id: operation_id,
      operation_type: NotificationConstants::OperationType::ASSET_COMPRESSION,
      operation_status: NotificationConstants::OperationStatus::QUEUED,
      message: admin_asset_message(MessageService::Admin::Asset::COMPRESSION_ENQUEUED),
      link: "/admin/assets/#{@asset.id}",
      data: { asset_id: @asset.id }
    )

    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::COMPRESSION_ENQUEUED),
      data: {
        asset: AssetSerializer.new(@asset.reload).serializable_hash[:data][:attributes],
        operation_id: operation_id,
        operation_type: NotificationConstants::OperationType::ASSET_COMPRESSION,
        operation_status: NotificationConstants::OperationStatus::QUEUED,
        link: "/admin/assets/#{@asset.id}"
      }
    )
  end

  def read_download
    filename = File.basename(@asset.name).gsub(/[\r\n"]/, "_")
    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::ASSET_RETRIEVED),
      data: { download_url: @asset.storage_url(response_content_disposition: %(attachment; filename="#{filename}")) }
    )
  end

  def update_thumbnail_regenerate
    unless @asset.compressible_video?
      message = admin_asset_message(MessageService::Admin::Asset::VIDEO_REQUIRED)
      render_json_response(status_code: 422, message: message, error: message)
      return
    end

    operation_id = "#{NotificationConstants::OperationType::VIDEO_THUMBNAIL}:#{@asset.id}:#{SecureRandom.uuid}"
    Media::GenerateVideoThumbnailJob.perform_later(
      asset_id: @asset.id,
      replace: true,
      notification_user_id: current_user.id,
      operation_id: operation_id
    )
    NotificationService::Center.operation(
      user_id: current_user.id,
      operation_id: operation_id,
      operation_type: NotificationConstants::OperationType::VIDEO_THUMBNAIL,
      operation_status: NotificationConstants::OperationStatus::QUEUED,
      message: admin_asset_message(MessageService::Admin::Asset::THUMBNAIL_REGENERATION_QUEUED),
      link: "/admin/assets/#{@asset.id}",
      data: { asset_id: @asset.id }
    )
    render_json_response(
      status_code: 202,
      message: admin_asset_message(MessageService::Admin::Asset::THUMBNAIL_REGENERATION_QUEUED),
      data: {
        asset: AssetSerializer.new(@asset.reload).serializable_hash[:data][:attributes],
        operation_id: operation_id,
        operation_type: NotificationConstants::OperationType::VIDEO_THUMBNAIL,
        operation_status: NotificationConstants::OperationStatus::QUEUED,
        link: "/admin/assets/#{@asset.id}"
      }
    )
  end

  def update_thumbnail_upload
    file = params[:file]
    unless @asset.thumbnail_attachable? && file.present? && file.content_type.to_s.start_with?("image/")
      message = admin_asset_message(MessageService::Admin::Asset::THUMBNAIL_IMAGE_REQUIRED)
      render_json_response(status_code: 422, message: message, error: message)
      return
    end

    result = nil
    conversion = nil
    begin
      conversion = MediaService::SvgToPng.prepare(file)
      result = StorageService::Client.upload(
        conversion.file,
        storage_key: AssetConstants::AssetName.thumbnail_for(
          @asset,
          version: SecureRandom.uuid,
          extension: conversion.converted? ? MediaConstants::IMAGE_EXT_PNG : MediaConstants::IMAGE_EXT_WEBP
        ),
        resource_type: "image"
      )
      fallback_size = conversion.converted? ? File.size(conversion.file) : file.size
      replace_thumbnail!(
        @asset,
        result,
        fallback_size: fallback_size,
        status: conversion.converted? ? MediaConstants::Status::OPTIMAL : MediaConstants::Status::READY
      )
      render_json_response(
        status_code: 200,
        message: admin_asset_message(MessageService::Admin::Asset::THUMBNAIL_REPLACED),
        data: { asset: AssetSerializer.new(@asset.reload).serializable_hash[:data][:attributes] }
      )
    rescue MediaService::ConversionError => e
      StorageService::Client.delete(result[:storage_key]) if result&.dig(:storage_key)
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::SAVE_FAILED),
        error: e.message
      )
    rescue StandardError
      StorageService::Client.delete(result[:storage_key]) if result&.dig(:storage_key)
      raise
    ensure
      MediaService::SvgToPng.cleanup(conversion)
    end
  end

  def update_subtitle_upload
    file = params[:file]
    unless @asset.subtitle_attachable?
      message = admin_asset_message(MessageService::Admin::Asset::SUBTITLE_PARENT_REQUIRED)
      render_json_response(status_code: 422, message: message, error: message)
      return
    end

    unless srt_upload?(file)
      message = admin_asset_message(MessageService::Admin::Asset::SUBTITLE_SRT_REQUIRED)
      render_json_response(status_code: 422, message: message, error: message)
      return
    end

    result = nil
    begin
      result = StorageService::Client.upload(
        file,
        storage_key: AssetConstants::AssetName.subtitle_for(@asset, version: SecureRandom.uuid),
        resource_type: "raw"
      )
      replace_subtitle!(@asset, result, fallback_size: file.size)
      render_json_response(
        status_code: 200,
        message: admin_asset_message(MessageService::Admin::Asset::SUBTITLE_REPLACED),
        data: { asset: AssetSerializer.new(@asset.reload).serializable_hash[:data][:attributes] }
      )
    rescue StandardError
      StorageService::Client.delete(result[:storage_key]) if result&.dig(:storage_key)
      raise
    end
  end

  private

  def replace_thumbnail!(asset, result, fallback_size:, status: MediaConstants::Status::READY)
    Asset.transaction do
      asset.thumbnail&.destroy!
      Asset.create!(
        name: result[:storage_key], url: result[:url],
        type: AssetConstants::AssetType::THUMBNAIL,
        format: AssetConstants::AssetFormat::IMAGE,
        extension: result[:format].presence || MediaConstants::IMAGE_EXT_WEBP,
        size_bytes: result[:bytes] || fallback_size,
        source: AssetConstants::AssetSource::UPLOAD,
        status: status,
        storage_key: result[:storage_key], assetable: asset.assetable,
        parent_asset: asset, created_by_id: current_user.id
      )
    end
  end

  def replace_subtitle!(asset, result, fallback_size:)
    Asset.transaction do
      asset.subtitle&.destroy!
      Asset.create!(
        name: result[:storage_key], url: result[:url],
        type: AssetConstants::AssetType::SUBTITLE,
        format: AssetConstants::AssetFormat::SUBTITLE,
        extension: MediaConstants::SUBTITLE_EXT_SRT,
        size_bytes: result[:bytes] || fallback_size,
        source: AssetConstants::AssetSource::UPLOAD,
        status: MediaConstants::Status::READY,
        storage_key: result[:storage_key], assetable: asset.assetable,
        parent_asset: asset, created_by_id: current_user.id
      )
    end
  end

  def srt_upload?(file)
    file.present? && AssetConstants::AssetFormat::SUBTITLE_EXTENSIONS.include?(
      File.extname(filename_for(file)).delete(".").downcase
    )
  end

  def admin_asset_message(key, **options)
    MessageService::Admin::Asset.t(key, **options)
  end

  def set_active_asset
    @asset = Asset.kept.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: admin_asset_message(MessageService::Admin::Asset::NOT_FOUND)
    )
  end

  def set_asset_including_discarded
    @asset = Asset.with_discarded.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: admin_asset_message(MessageService::Admin::Asset::NOT_FOUND)
    )
  end

  def admin_asset_params
    params.require(:asset).permit(:name, :type, :assetable_type, :assetable_id)
  end

  def search_assets(scope)
    search = params[:search].to_s.strip
    return scope if search.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search)}%"
    scope.where(
      "assets.name ILIKE :search OR assets.storage_key ILIKE :search OR assets.assetable_type ILIKE :search",
      search: pattern
    )
  end

  def filter_assets(scope)
    scope = scope.where(type: params[:type]) if params[:type].present?
    scope = scope.where(format: params[:format]) if params[:format].present?
    scope = scope.where(source: params[:source]) if params[:source].present?
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope
  end

  def filename_for(file_or_name)
    file_or_name.respond_to?(:original_filename) ? file_or_name.original_filename.to_s : file_or_name.to_s
  end

  def determine_resource_type(file_or_name)
    ext = File.extname(filename_for(file_or_name)).delete(".").downcase
    AssetConstants::AssetFormat.storage_resource_type(ext)
  end

  def determine_asset_format(file_or_name)
    ext = File.extname(filename_for(file_or_name)).delete(".").downcase
    AssetConstants::AssetFormat.from_extension(ext)
  end

  # ── Media Compression Helpers ───────────────────────────────

  def compression_status_for(file)
    if MediaConstants::MEDIA_CONTAINER_ENABLED && file_compressible?(file)
      MediaConstants::Status::PENDING
    else
      MediaConstants::Status::READY
    end
  end

  def enqueue_compression_if_needed(asset)
    return unless asset.status == MediaConstants::Status::PENDING

    if asset.compressible_video?
      Media::CompressVideoJob.perform_later(asset_id: asset.id)
      Media::GenerateVideoThumbnailJob.perform_later(asset_id: asset.id)
      Rails.logger.info("[AssetsController] Enqueued video compression for asset #{asset.id}")
    elsif asset.compressible_image?
      Media::CompressImageJob.perform_later(asset_id: asset.id)
      Rails.logger.info("[AssetsController] Enqueued image compression for asset #{asset.id}")
    elsif asset.compressible_audio?
      Media::CompressAudioJob.perform_later(asset_id: asset.id)
      Rails.logger.info("[AssetsController] Enqueued audio compression for asset #{asset.id}")
    end
  end

  def file_compressible?(file)
    filename = file.respond_to?(:original_filename) ? file.original_filename : file.to_s
    ext = File.extname(filename).delete(".").downcase
    MediaConstants::COMPRESSIBLE_VIDEO_EXTENSIONS.include?(ext) ||
      MediaConstants::COMPRESSIBLE_IMAGE_EXTENSIONS.include?(ext) ||
      MediaConstants::COMPRESSIBLE_AUDIO_EXTENSIONS.include?(ext)
  end
end
