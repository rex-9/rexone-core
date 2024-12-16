class AssetsController < ApplicationController
  before_action :set_asset, only: %i[show update destroy]

  # GET /assets
  def index
    @assets = Asset.all
    render json: @assets
  end

  # GET /assets/1
  def show
    render json: @asset
  end

  # POST /assets/upload
  def upload
    file = params[:file]
    if file
      public_id = "profile_upload_#{File.basename(file.original_filename, '.*')}_of_user_#{current_user.id}"
      result = Cloudinary::Uploader.upload(file.path, public_id: public_id)
      asset = Asset.find_or_initialize_by(url: result["secure_url"])
      # override if url already exists
      asset.assign_attributes(
        name: result["public_id"],
        category: "profile",
        size: result["bytes"],
        source: "upload",
        user: current_user
      )
      if asset.save
        render json: { url: asset.url }, status: :created
      else
        render json: asset.errors, status: :unprocessable_entity
      end
    else
      render json: { error: "No file uploaded" }, status: :unprocessable_entity
    end
  end

  # POST /assets
  def create
    @asset = Asset.new(asset_params)

    if @asset.save
      render json: @asset, status: :created, location: @asset
    else
      render json: @asset.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /assets/1
  def update
    if @asset.update(asset_params)
      render json: @asset
    else
      render json: @asset.errors, status: :unprocessable_entity
    end
  end

  # DELETE /assets/1
  def destroy
    @asset.destroy!
  end

  private

  def set_asset
    @asset = Asset.find(params[:id])
  end

  def asset_params
    params.require(:asset).permit(:name, :url, :category, :size, :source, :user_id)
  end
end
