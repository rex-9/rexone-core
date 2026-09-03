# app/controllers/v1/admin/assets_controller.rb

class V1::Admin::AssetsController < V1::ApplicationController
  before_action :set_active_asset, only: %i[show update discard]
  before_action :set_asset_including_discarded, only: %i[undiscard destroy]

  # GET /v1/admin/assets
  def index
    assets = search_assets(Asset.kept)
    assets = filter_assets(assets)
    assets = sort(assets, columns: SortConstants::Columns::ASSET)
    pagy, records = pagy(:offset, assets, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::ASSETS_RETRIEVED),
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

    asset_type = params[:type].presence || AssetConstants::AssetType::GENERAL
    assetable_type = params[:assetable_type].presence
    assetable_id = params[:assetable_id].presence
    duration_secs = params[:duration_secs]

    storage_key = "#{File.basename(file.original_filename, '.*')}_of_user_#{current_user.id}_#{Time.now.to_i}"

    result = StorageService::Client.upload(
      file,
      storage_key: storage_key,
      folder: params[:folder].presence || "admin_uploads/#{asset_type}",
      resource_type: determine_resource_type(file),
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
      format: determine_asset_format(file),
      size_bytes: result[:bytes],
      duration_secs: duration_secs,
      source: AssetConstants::AssetSource::UPLOAD,
      assetable_type: assetable_type,
      assetable_id: assetable_id,
      storage_key: result[:storage_key],
      extension: result[:format] || File.extname(file.original_filename).delete(".")
    )

    if asset.save
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
      StorageService::Client.delete_later(
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
    render_json_response(
      status_code: 500,
      message: admin_asset_message(MessageService::Admin::Asset::STORAGE_UPLOAD_FAILED),
      error: e.message
    )
  end

  # PUT /v1/admin/assets/:id
  def update
    if @asset.update(admin_asset_params)
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

  # GET /v1/admin/assets/discarded
  def read_discarded
    assets = search_assets(Asset.with_discarded.discarded)
    assets = filter_assets(assets)
    assets = sort(assets, columns: SortConstants::Columns::ASSET, default_column: "discarded_at")
    pagy, records = pagy(:offset, assets, limit: params[:limit])

    render_json_response(
      status_code: 200,
      message: admin_asset_message(MessageService::Admin::Asset::DISCARDED_ASSETS_RETRIEVED),
      data: AssetSerializer.paginated(records, pagy),
      pagy: pagy
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

  private

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
    scope
  end

  def determine_resource_type(file)
    ext = File.extname(file.original_filename).delete(".").downcase
    AssetConstants::AssetFormat.storage_resource_type(ext)
  end

  def determine_asset_format(file)
    ext = File.extname(file.original_filename).delete(".").downcase
    AssetConstants::AssetFormat.from_extension(ext)
  end
end
