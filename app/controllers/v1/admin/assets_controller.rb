# app/controllers/v1/admin/assets_controller.rb

class V1::Admin::AssetsController < V1::ApplicationController
  before_action :super_admin_required!, only: :read_storage_stats
  before_action :set_active_asset, only: %i[show update discard update_compress read_download update_thumbnail_regenerate update_thumbnail_upload update_subtitle_upload]
  before_action :set_asset_including_discarded, only: %i[undiscard destroy]

  # GET /v1/admin/assets
  def index
    filters = filter_params
    discarded = filters[:discarded].to_s == "true"
    scope = discarded ? Asset.with_discarded.discarded : Asset.kept
    scope = scope.includes(:thumbnail, :subtitles)
    assets = search_assets(scope)
    assets = filter_assets(assets)
    assets = if discarded
      sort(assets, columns: SortConstants::Columns::ASSET, default_column: "discarded_at")
    else
      sort(assets, columns: SortConstants::Columns::ASSET)
    end
    pagy, records = pagy(:offset, assets, limit: filters[:limit])

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
    @asset.association(:thumbnail).load_target
    @asset.association(:subtitles).load_target

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
    upload = upload_params
    file = upload[:file]

    if file.blank?
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::NO_FILE_UPLOADED),
        error: admin_asset_message(MessageService::Admin::Asset::FILE_REQUIRED)
      )
      return
    end

    max_size_mb = upload_limit_mb(file)

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

    asset_type = upload[:type].presence || AssetConstants::AssetType::GENERAL
    assetable_type = upload[:assetable_type].presence
    assetable_id = upload[:assetable_id].presence
    duration_secs = upload[:duration_secs]
    title = upload[:title].presence || (file.respond_to?(:original_filename) ? file.original_filename : nil)
    description = upload[:description].presence

    begin
      storage_key = AssetConstants::AssetName.for_admin(type: asset_type, original_filename: file.original_filename)

      result = StorageService::Client.upload(
        file,
        storage_key: storage_key,
        resource_type: determine_resource_type(file),
        metadata: {
          user_id: current_user.id.to_s,
          original_filename: file.original_filename
        }
      )

      asset = Asset.find_or_initialize_by(storage_key: result[:storage_key])
      asset.assign_attributes(
        name: result[:storage_key],
        title: title,
        description: description,
        url: result[:url],
        type: asset_type,
        format: determine_asset_format(file),
        size_bytes: result[:bytes],
        duration_secs: duration_secs,
        source: AssetConstants::AssetSource::UPLOAD,
        assetable_type: assetable_type,
        assetable_id: assetable_id,
        storage_key: result[:storage_key],
        extension: result[:format] || File.extname(filename_for(file)).delete("."),
        status: processing_status_for(file)
      )

      if asset.save
        enqueue_media_processing_if_needed(asset)

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
    rescue StorageService::Error => e
      Rails.error.report(e)
      message = admin_asset_message(MessageService::Admin::Asset::STORAGE_UPLOAD_FAILED)
      render_json_response(
        status_code: 500,
        message: message,
        error: message
      )
    end
  end

  # PUT /v1/admin/assets/:id
  def update
    update_params = admin_asset_params
    new_type = update_params[:type].presence

    if @asset.parent_asset_id.present? && new_type.present? && new_type != @asset.type
      render_json_response(
        status_code: 422,
        message: admin_asset_message(MessageService::Admin::Asset::UPDATE_FAILED),
        error: "Child asset type cannot be changed"
      )
      return
    end

    if new_type.present? && new_type != @asset.type
      if @asset.uploaded_file? && @asset.storage_key.present?
        new_storage_key = AssetConstants::AssetName.rename_type(@asset.storage_key, new_type, @asset.type)
        if new_storage_key != @asset.storage_key
          Rails.logger.info("[AssetsController] Renaming storage object: #{@asset.storage_key} -> #{new_storage_key}")
          StorageService::Client.move(@asset.storage_key, new_storage_key)
          @asset.storage_key = new_storage_key
          @asset.url = StorageService::Client.url(new_storage_key)
        end
        update_params = update_params.merge(name: new_storage_key)
      elsif @asset.name.present?
        new_name = AssetConstants::AssetName.rename_type(@asset.name, new_type, @asset.type)
        update_params = update_params.merge(name: new_name)
      end
    elsif @asset.storage_key.present?
      update_params = update_params.except(:name)
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
    ids = Array(batch_params[:ids]).compact_blank
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
    ids = Array(batch_params[:ids]).compact_blank
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
    ids = Array(batch_params[:ids]).compact_blank
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
      Media::CompressMediaJob.perform_later(
        asset_id: @asset.id,
        notification_user_id: current_user.id,
        operation_id: operation_id
      )
    elsif @asset.compressible_image?
      Media::CompressMediaJob.perform_later(asset_id: @asset.id, notification_user_id: current_user.id, operation_id: operation_id)
    elsif @asset.compressible_audio?
      Media::CompressMediaJob.perform_later(asset_id: @asset.id, notification_user_id: current_user.id, operation_id: operation_id)
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
    file = upload_file_param[:file]
    unless @asset.thumbnail_attachable? && file.present? && file.content_type.to_s.start_with?("image/")
      message = admin_asset_message(MessageService::Admin::Asset::THUMBNAIL_IMAGE_REQUIRED)
      render_json_response(status_code: 422, message: message, error: message)
      return
    end

    unless upload_within_limit?(file)
      render_file_size_exceeded(file)
      return
    end

    result = nil
    begin
      extension = File.extname(filename_for(file)).delete(".").downcase
      result = StorageService::Client.upload(
        file,
        storage_key: AssetConstants::AssetName.thumbnail_for(
          @asset,
          version: SecureRandom.uuid,
          extension: extension
        ),
        resource_type: "image"
      )
      thumbnail = replace_thumbnail!(
        @asset,
        result,
        fallback_size: file.size,
        status: processing_status_for(file)
      )
      enqueue_media_processing_if_needed(thumbnail)
      render_json_response(
        status_code: 200,
        message: admin_asset_message(MessageService::Admin::Asset::THUMBNAIL_REPLACED),
        data: { asset: AssetSerializer.new(@asset.reload).serializable_hash[:data][:attributes] }
      )
    rescue StandardError
      StorageService::Client.delete(result[:storage_key]) if result&.dig(:storage_key)
      raise
    end
  end

  def update_subtitle_upload
    file = upload_file_param[:file]
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


    unless upload_within_limit?(file)
      render_file_size_exceeded(file)
      return
    end

    result = nil
    begin
      result = StorageService::Client.upload(
        file,
        storage_key: AssetConstants::AssetName.subtitle_for(@asset, version: SecureRandom.uuid),
        resource_type: "raw"
      )
      create_subtitle!(@asset, result, fallback_size: file.size)
      render_json_response(
        status_code: 200,
        message: admin_asset_message(MessageService::Admin::Asset::SUBTITLE_UPLOADED),
        data: { asset: AssetSerializer.new(@asset.reload).serializable_hash[:data][:attributes] }
      )
    rescue StandardError
      StorageService::Client.delete(result[:storage_key]) if result&.dig(:storage_key)
      raise
    end
  end

  private

  def replace_thumbnail!(asset, result, fallback_size:, status: MediaConstants::Status::READY)
    previous_storage_key = nil
    thumbnail = Asset.transaction do
      existing = Asset.find_by(
        parent_asset_id: asset.id,
        type: AssetConstants::AssetType::THUMBNAIL
      )
      previous_storage_key = existing&.storage_key
      attributes = {
        name: result[:storage_key], url: result[:url],
        type: AssetConstants::AssetType::THUMBNAIL,
        format: AssetConstants::AssetFormat::IMAGE,
        extension: result[:format].presence || MediaConstants::IMAGE_EXT_WEBP,
        size_bytes: result[:bytes] || fallback_size,
        source: AssetConstants::AssetSource::UPLOAD,
        status: status,
        storage_key: result[:storage_key], assetable: asset.assetable,
        parent_asset: asset, created_by_id: current_user.id
      }

      if existing
        existing.update!(attributes)
        existing
      else
        Asset.create!(attributes)
      end
    end

    delete_replaced_storage(previous_storage_key, thumbnail.storage_key, resource_type: "image")
    asset.association(:thumbnail).reset
    thumbnail
  end

  def create_subtitle!(asset, result, fallback_size:)
    Asset.transaction do
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
    file.present? && file.content_type.to_s.in?(MediaConstants::SUBTITLE_CONTENT_TYPES) && AssetConstants::AssetFormat::SUBTITLE_EXTENSIONS.include?(
      File.extname(filename_for(file)).delete(".").downcase
    )
  end

  def delete_replaced_storage(previous_key, replacement_key, resource_type:)
    return if previous_key.blank? || previous_key == replacement_key

    StorageService::Client.delete(previous_key, resource_type: resource_type)
  rescue StandardError => error
    Rails.error.report(error)
    Rails.logger.error("[AssetsController] Failed to delete replaced storage object #{previous_key}: #{error.message}")
  end

  def admin_asset_message(key, **options)
    MessageService::Admin::Asset.t(key, **options)
  end

  def set_active_asset
    @asset = Asset.kept.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: admin_asset_message(MessageService::Admin::Asset::NOT_FOUND)
    )
  end

  def set_asset_including_discarded
    @asset = Asset.with_discarded.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: admin_asset_message(MessageService::Admin::Asset::NOT_FOUND)
    )
  end

  def upload_params
    params.permit(:file, :type, :assetable_type, :assetable_id, :duration_secs, :title, :description)
  end

  def upload_file_param
    params.permit(:file)
  end

  def batch_params
    params.permit(ids: [])
  end

  def admin_asset_params
    params.require(:asset).permit(:name, :title, :description, :type, :assetable_type, :assetable_id)
  end

  def filter_params
    params.permit(:search, :type, :format, :source, :status, :record_scope, :discarded, :limit, :page)
  end

  def search_assets(scope)
    search = filter_params[:search].to_s.strip
    return scope if search.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search)}%"
    scope.where(
      "assets.name ILIKE :search OR assets.title ILIKE :search OR assets.storage_key ILIKE :search OR assets.assetable_type ILIKE :search",
      search: pattern
    )
  end

  def filter_assets(scope)
    filters = filter_params
    scope = scope.where(type: filters[:type]) if filters[:type].present?
    scope = scope.where(format: filters[:format]) if filters[:format].present?
    scope = scope.where(source: filters[:source]) if filters[:source].present?
    scope = scope.where(status: filters[:status]) if filters[:status].present?
    filter_asset_record_scope(scope, filters[:record_scope])
  end

  def filter_asset_record_scope(scope, record_scope = filter_params[:record_scope])
    case record_scope.presence
    when AssetConstants::RecordScope::CHILDREN
      scope.where.not(parent_asset_id: nil)
    when AssetConstants::RecordScope::ALL
      scope
    else
      scope.where(parent_asset_id: nil)
    end
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

  def upload_limit_mb(file_or_name)
    ext = File.extname(filename_for(file_or_name)).delete(".").downcase
    AssetConstants::AssetFormat.upload_limit_mb(ext)
  end

  def upload_within_limit?(file)
    file.size <= upload_limit_mb(file).megabytes
  end

  def render_file_size_exceeded(file)
    limit = upload_limit_mb(file)
    message = admin_asset_message(MessageService::Admin::Asset::SAVE_FAILED)
    render_json_response(
      status_code: 422,
      message: message,
      error: admin_asset_message(MessageService::Admin::Asset::FILE_SIZE_EXCEEDED, limit: limit)
    )
  end

  # ── Media Processing Helpers ───────────────────────────────

  def processing_status_for(file)
    if MediaConstants::MEDIA_CONTAINER_ENABLED && file_processable?(file)
      MediaConstants::Status::PENDING
    else
      MediaConstants::Status::READY
    end
  end

  def enqueue_media_processing_if_needed(asset)
    return unless asset.status == MediaConstants::Status::PENDING

    if asset.image_convertible?
      Media::ConvertImageJob.perform_later(asset_id: asset.id)
      Rails.logger.info("[AssetsController] Enqueued image conversion for asset #{asset.id}")
    elsif asset.compressible_video?
      Media::CompressMediaJob.perform_later(asset_id: asset.id)
      Media::GenerateVideoThumbnailJob.perform_later(asset_id: asset.id)
      Rails.logger.info("[AssetsController] Enqueued video compression for asset #{asset.id}")
    elsif asset.compressible_image?
      Media::CompressMediaJob.perform_later(asset_id: asset.id)
      Rails.logger.info("[AssetsController] Enqueued image compression for asset #{asset.id}")
    elsif asset.compressible_audio?
      Media::CompressMediaJob.perform_later(asset_id: asset.id)
      Rails.logger.info("[AssetsController] Enqueued audio compression for asset #{asset.id}")
    end
  end

  def file_processable?(file)
    ext = File.extname(filename_for(file)).delete(".").downcase
    MediaConstants::Processing::ALL_EXTENSIONS.include?(ext)
  end
end
