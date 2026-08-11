# app/controllers/v1/assets_controller.rb
class V1::AssetsController < V1::ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show ]
  before_action :set_asset, only: [ :show, :update, :destroy ]

  # GET /assets
  def index
    assets = Asset.all

    render_json_response(
      status_code: 200,
      message: "Assets fetched successfully",
      data: {
        assets: AssetSerializer.new(assets).serializable_hash[:data]
      }
    )
  end

  # GET /assets/:id
  def show
    render_json_response(
      status_code: 200,
      message: "Asset fetched successfully",
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
        message: "No file uploaded",
        error: "File parameter is required"
      )
      return
    end

    # Generate public_id
    public_id = "#{params[:category] || 'profile'}/#{File.basename(file.original_filename, '.*')}_of_user_#{current_user.id}_#{Time.now.to_i}"

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
      format: result[:format] || determine_resource_type(file),
      size: result[:bytes],
      source: "upload",
      user: current_user,
      public_id: result[:public_id],
      extension: result[:format] || File.extname(file.original_filename).delete(".")
    )

    if asset.save
      render_json_response(
        status_code: 201,
        message: "Asset uploaded successfully",
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
      # Try to delete from storage if database save fails
      StorageService::Client.delete(public_id) rescue nil

      render_json_response(
        status_code: 422,
        message: "Failed to save asset",
        error: asset.errors.full_messages.to_sentence
      )
    end
  rescue StorageService::Error => e
    render_json_response(
      status_code: 500,
      message: "Storage upload failed",
      error: e.message
    )
  end

  # POST /assets
  def create
    asset = Asset.new(asset_params)

    if asset.save
      render_json_response(
        status_code: 201,
        message: "Asset created successfully",
        data: {
          asset: AssetSerializer.new(asset).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: "Failed to create asset",
        error: asset.errors.full_messages.to_sentence
      )
    end
  end

  # PUT /assets/:id
  def update
    if @asset.update(asset_params)
      render_json_response(
        status_code: 200,
        message: "Asset updated successfully",
        data: {
          asset: AssetSerializer.new(@asset).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: "Failed to update asset",
        error: @asset.errors.full_messages.to_sentence
      )
    end
  end

  # DELETE /assets/:id
  def destroy
    @asset.destroy!

    render_json_response(
      status_code: 200,
      message: "Asset deleted successfully"
    )
  rescue ActiveRecord::RecordNotDestroyed => e
    render_json_response(
      status_code: 422,
      message: "Failed to delete asset",
      error: e.message
    )
  end

  # POST /assets/:id/refresh_url
  def create_refresh_url
    set_asset

    if @asset.refresh_url
      render_json_response(
        status_code: 200,
        message: "Asset URL refreshed successfully",
        data: {
          asset: AssetSerializer.new(@asset.reload).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: "Failed to refresh asset URL"
      )
    end
  end

  # GET /assets/list
  def read_list
    prefix = params[:prefix] || ""
    assets = StorageService::Client.list(prefix)

    render_json_response(
      status_code: 200,
      message: "Storage assets listed successfully",
      data: {
        assets: assets
      }
    )
  rescue StorageService::Error => e
    render_json_response(
      status_code: 500,
      message: "Failed to list storage assets",
      error: e.message
    )
  end

  private

  def set_asset
    @asset = Asset.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_json_response(
      status_code: 404,
      message: "Asset not found"
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
      "doc"
    else
      "auto"
    end
  end
end
