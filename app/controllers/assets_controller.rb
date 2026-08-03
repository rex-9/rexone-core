# app/controllers/assets_controller.rb

class AssetsController < ApplicationController
  before_action :authenticate_user!, except: [ :index, :show ]
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
  def upload
    file = params[:file]

    if file.blank?
      render_json_response(
        status_code: 422,
        message: "No file uploaded",
        error: "File parameter is required"
      )
      return
    end

    public_id = "profile_upload_#{File.basename(file.original_filename, '.*')}_of_user_#{current_user.id}"
    result = Cloudinary::Uploader.upload(file.path, public_id: public_id)

    asset = Asset.find_or_initialize_by(url: result["secure_url"])
    asset.assign_attributes(
      name: result["public_id"],
      category: params[:category] || "profile",
      format: "image",
      size: result["bytes"],
      source: "upload",
      user: current_user
    )

    if asset.save
      render_json_response(
        status_code: 201,
        message: "Asset uploaded successfully",
        data: {
          asset: AssetSerializer.new(asset).serializable_hash[:data][:attributes]
        }
      )
    else
      render_json_response(
        status_code: 422,
        message: "Failed to save asset",
        error: asset.errors.full_messages.to_sentence
      )
    end
  rescue Cloudinary::Error => e
    render_json_response(
      status_code: 500,
      message: "Cloudinary upload failed",
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
  end

  private

  def set_asset
    @asset = Asset.find(params[:id])
  end

  def asset_params
    params.require(:asset).permit(:name, :url, :category, :format, :extension, :size, :source, :record_id, :record_type, :user_id)
  end
end
