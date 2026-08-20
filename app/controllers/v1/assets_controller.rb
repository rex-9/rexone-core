# app/controllers/v1/assets_controller.rb
class V1::AssetsController < V1::ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_asset, only: [ :show, :update, :destroy ]

  # GET /assets?page=1&limit=10
  def index
    assets = Asset.all
    pagy, records = pagy(:offset, assets, limit: params[:limit])

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

  # POST /assets/upload
  def create_upload
    file = params[:file]

    if file.blank?
      render_json_response(
        status_code: 422,
        message: asset_message(MessageService::Asset::NO_FILE_UPLOADED),
        error: asset_message(MessageService::Asset::FILE_REQUIRED)
      )
      return
    end

    # Generate public_id
    public_id = "#{File.basename(file.original_filename, '.*')}_of_user_#{current_user.id}_#{Time.now.to_i}"

    # Upload to storage service
    result = StorageService::Client.upload(
      file,
      public_id: public_id,
      folder: params[:category] || "profile",
      resource_type: determine_resource_type(file),
      metadata: {
        user_id: current_user.id.to_s,
        original_filename: file.original_filename
      }
    )

    # Find or create asset
    asset = Asset.find_or_initialize_by(public_id: result[:public_id])
    asset.assign_attributes(
      name: result[:public_id],
      url: result[:url],
      category: params[:category] || "profile",
      format: determine_asset_format(file),
      size: result[:bytes],
      source: "upload",
      user: current_user,
      public_id: result[:public_id],
      extension: result[:format] || File.extname(file.original_filename).delete(".")
    )

    if asset.save
      render_json_response(
        status_code: 201,
        message: asset_message(MessageService::Asset::UPLOADED),
        data: {
          asset: AssetSerializer.new(asset).serializable_hash[:data][:attributes],
          storage_details: {
            public_id: result[:public_id],
            bytes: result[:bytes],
            format: result[:format]
          }
        }
      )
    else
      StorageService::Client.delete_later(
        result[:public_id],
        resource_type: result[:resource_type]
      )

      render_json_response(
        status_code: 422,
        message: asset_message(MessageService::Asset::SAVE_FAILED),
        error: asset.errors.full_messages.to_sentence
      )
    end
  rescue StorageService::Error => e
    render_json_response(
      status_code: 500,
      message: asset_message(MessageService::Asset::STORAGE_UPLOAD_FAILED),
      error: e.message
    )
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
    prefix = params[:prefix] || ""
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

  def asset_message(key, **options)
    MessageService::Asset.t(key, **options)
  end

  def set_asset
    @asset = Asset.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: asset_message(MessageService::Asset::NOT_FOUND)
    )
  end

  def asset_params
    params.require(:asset).permit(:name, :url, :category, :format, :extension, :size, :source, :record_id, :record_type, :user_id, :public_id)
  end

  def determine_resource_type(file)
    extension = File.extname(file.original_filename).delete(".").downcase

    case extension
    when "jpg", "jpeg", "png", "gif", "webp", "svg"
      "image"
    when "mp4", "mov", "avi", "webm", "mkv"
      "video"
    when "pdf", "doc", "docx", "txt", "rtf"
      "raw"
    else
      "auto"
    end
  end

  def determine_asset_format(file)
    resource_type = determine_resource_type(file)

    case resource_type
    when "image", "video"
      resource_type
    when "raw"
      "doc"
    else
      "unknown"
    end
  end
end
