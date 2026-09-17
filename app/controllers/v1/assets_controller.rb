# app/controllers/v1/assets_controller.rb
class V1::AssetsController < V1::ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_asset, only: [ :show, :update, :destroy, :read_playback ]

  # GET /v1/assets?type=video&page=1&limit=10
  def index
    filters = filter_params
    assets = Asset.includes(:thumbnail, :subtitles)
    assets = assets.where(type: filters[:type]) if filters[:type].present?
    assets = filter_asset_record_scope(assets, filters[:record_scope])
    pagy, records = pagy(:offset, assets, limit: filters[:limit])

    render_json_response(
      status_code: 200,
      message: asset_message(MessageService::Asset::FETCHED),
      data: AssetSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /assets/:id
  def show
    render_json_response(
      status_code: 200,
      message: asset_message(MessageService::Asset::FETCHED_ONE),
      data: {
        asset: AssetSerializer.new(@asset).serializable_hash[:data][:attributes]
      }
    )
  end

  # GET /v1/assets/:id/playback
  def read_playback
    unless @asset.playable_format?
      message = asset_message(MessageService::Asset::PLAYBACK_UNSUPPORTED)
      render_json_response(status_code: 422, message: message, error: message)
      return
    end

    unless @asset.storage_key.present?
      message = asset_message(MessageService::Asset::PLAYBACK_STORAGE_MISSING)
      render_json_response(status_code: 422, message: message, error: message)
      return
    end

    unless @asset.playable_status?
      message = asset_message(MessageService::Asset::PLAYBACK_NOT_READY)
      render_json_response(status_code: 409, message: message, error: message)
      return
    end

    delivery = StorageService::Client.playback_url(
      @asset,
      expires_in: MediaConstants::PLAYBACK_URL_TTL
    )

    render_json_response(
      status_code: 200,
      message: asset_message(MessageService::Asset::PLAYBACK_READY),
      data: playback_payload(@asset, delivery)
    )
  rescue StorageService::Error => e
    Rails.logger.error("[AssetsController] Playback URL failed for asset #{@asset&.id}: #{e.class}")
    message = asset_message(MessageService::Asset::PLAYBACK_STORAGE_FAILED)
    render_json_response(status_code: 503, message: message, error: message)
  end

  # POST /assets/upload
  def create_upload
    upload = upload_params
    file = upload[:file]

    if file.blank?
      render_json_response(
        status_code: 422,
        message: asset_message(MessageService::Asset::NO_FILE_UPLOADED),
        error: asset_message(MessageService::Asset::FILE_REQUIRED)
      )
      return
    end

    max_size_mb = upload_limit_mb(file)

    if file.size > max_size_mb.megabytes
      render_json_response(
        status_code: 422,
        message: asset_message(MessageService::Asset::SAVE_FAILED),
        error: asset_message(
          MessageService::Asset::FILE_SIZE_EXCEEDED,
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
      storage_key = AssetConstants::AssetName.for_user(user_id: current_user.id, type: asset_type, original_filename: file.original_filename)

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
        if asset.type == AssetConstants::AssetType::AVATAR && asset.assetable_type.to_s.downcase == AssetConstants::AssetName::USER_NAMESPACE && asset.assetable_id.present?
          old_avatars = Asset.where(type: AssetConstants::AssetType::AVATAR, assetable_type: asset.assetable_type, assetable_id: asset.assetable_id)
                             .where.not(id: asset.id)
          Asset.purge_and_destroy_all!(old_avatars)
        end
        render_json_response(
          status_code: 201,
          message: asset_message(MessageService::Asset::UPLOADED),
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
          message: asset_message(MessageService::Asset::SAVE_FAILED),
          error: asset.errors.full_messages.to_sentence
        )
      end
    rescue StorageService::Error => e
      Rails.error.report(e)
      message = asset_message(MessageService::Asset::STORAGE_UPLOAD_FAILED)
      render_json_response(
        status_code: 500,
        message: message,
        error: message
      )
    end
  end

  # POST /assets
  def create
    asset = Asset.new(asset_params)

    if asset.save
      render_json_response(
        status_code: 201,
        message: asset_message(MessageService::Asset::CREATED),
        data: {
          asset: AssetSerializer.new(asset).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: asset_message(MessageService::Asset::CREATE_FAILED),
        error: asset.errors.full_messages.to_sentence
      )
    end
  end

  # PUT /assets/:id
  def update
    if @asset.update(asset_params)
      render_json_response(
        status_code: 200,
        message: asset_message(MessageService::Asset::UPDATED),
        data: {
          asset: AssetSerializer.new(@asset).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: asset_message(MessageService::Asset::UPDATE_FAILED),
        error: @asset.errors.full_messages.to_sentence
      )
    end
  end

  # DELETE /assets/:id
  def destroy
    @asset.destroy!

    render_json_response(
      status_code: 200,
      message: asset_message(MessageService::Asset::DELETED)
    )
  rescue ActiveRecord::RecordNotDestroyed => e
    render_json_response(
      status_code: 422,
      message: asset_message(MessageService::Asset::DELETE_FAILED),
      error: e.message
    )
  end

  # POST /assets/:id/refresh_url
  def create_refresh_url
    set_asset

    if @asset.refresh_url
      render_json_response(
        status_code: 200,
        message: asset_message(MessageService::Asset::URL_REFRESHED),
        data: {
          asset: AssetSerializer.new(@asset.reload).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: asset_message(MessageService::Asset::URL_REFRESH_FAILED)
      )
    end
  end

  # GET /assets/list
  def read_list
    prefix = list_params[:prefix].to_s
    assets = StorageService::Client.list(prefix)

    render_json_response(
      status_code: 200,
      message: asset_message(MessageService::Asset::STORAGE_LISTED),
      data: {
        assets: assets
      }
    )
  rescue StorageService::Error => e
    render_json_response(
      status_code: 500,
      message: asset_message(MessageService::Asset::STORAGE_LIST_FAILED),
      error: e.message
    )
  end

  private

  def filter_params
    params.permit(:type, :limit, :record_scope)
  end

  def upload_params
    params.permit(:file, :type, :assetable_type, :assetable_id, :duration_secs, :title, :description)
  end

  def list_params
    params.permit(:prefix)
  end

  def asset_message(key, **options)
    MessageService::Asset.t(key, **options)
  end

  def set_asset
    @asset = Asset.find(params.permit(:id)[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: asset_message(MessageService::Asset::NOT_FOUND)
    )
  end

  def asset_params
    params.require(:asset).permit(:name, :title, :description, :url, :type, :format, :extension, :size_bytes, :duration_secs, :source, :assetable_type, :assetable_id)
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

  def playback_payload(asset, delivery)
    {
      asset_id: asset.id,
      delivery: {
        type: delivery.fetch(:type),
        url: delivery.fetch(:url),
        expires_at: delivery.fetch(:expires_at).iso8601
      },
      media: {
        content_type: asset.mime_type,
        format: asset.extension,
        size_bytes: asset.size_bytes,
        duration_secs: asset.duration_secs,
        thumbnail: asset.thumbnail ? AssetSerializer.new(asset.thumbnail).serializable_hash[:data][:attributes] : nil,
        subtitles: asset.subtitles.map { |subtitle| AssetSerializer.new(subtitle).serializable_hash[:data][:attributes] }
      }
    }
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
