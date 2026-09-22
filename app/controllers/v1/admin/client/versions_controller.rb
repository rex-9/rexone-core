class V1::Admin::Client::VersionsController < V1::ApplicationController
  before_action :super_admin_required!
  before_action :set_active_version, only: %i[show update discard read_user_versions]
  before_action :set_version_including_discarded, only: :undiscard

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  # GET /v1/admin/client/versions
  def index
    filters = filter_params
    discarded = filters[:discarded].to_s == "true"
    versions = discarded ? Client::Version.with_discarded.discarded.with_install_counts : Client::Version.with_install_counts
    versions = versions.where(status: filters[:status]) if filters[:status].present?
    versions = if discarded
      sort(versions, columns: SortConstants::Columns::VERSION, default_column: :discarded_at)
    else
      sort(versions, columns: SortConstants::Columns::VERSION)
    end
    pagy, records = pagy(versions)

    render_json_response(
      status_code: 200,
      message: version_message(discarded ? MessageService::Version::DISCARDED_FETCHED : MessageService::Version::FETCHED),
      data: Client::VersionAdminSerializer.paginated(records, pagy),
      pagy: pagy
    )
  end

  # GET /v1/admin/client/versions/:id
  def show
    render_json_response(
      status_code: 200,
      message: version_message(MessageService::Version::FETCHED),
      data: Client::VersionAdminSerializer.new(@version).serializable_hash[:data][:attributes]
    )
  end

  # POST /v1/admin/client/versions
  def create
    version = Client::Version.new(version_params)
    version.status ||= VersionConstants::Status::DRAFT

    if version.save
      render_json_response(
        status_code: 201,
        message: version_message(MessageService::Version::CREATED),
        data: Client::VersionAdminSerializer.new(version).serializable_hash[:data][:attributes]
      )
    else
      render_json_response(
        status_code: 422,
        message: version_message(MessageService::Version::CREATE_FAILED),
        error: version.errors.full_messages.to_sentence
      )
    end
  end

  # PUT /v1/admin/client/versions/:id
  def update
    if @version.update(version_params)
      render_json_response(
        status_code: 200,
        message: version_message(MessageService::Version::UPDATED),
        data: Client::VersionAdminSerializer.new(@version).serializable_hash[:data][:attributes]
      )
    else
      render_json_response(
        status_code: 422,
        message: version_message(MessageService::Version::UPDATE_FAILED),
        error: @version.errors.full_messages.to_sentence
      )
    end
  end

  # POST /v1/admin/client/versions/:id/discard
  def discard
    @version.discard!

    render_json_response(
      status_code: 200,
      message: version_message(MessageService::Version::DISCARDED)
    )
  end

  # POST /v1/admin/client/versions/:id/undiscard
  def undiscard
    @version.undiscard!

    render_json_response(
      status_code: 200,
      message: version_message(MessageService::Version::RESTORED),
      data: Client::VersionAdminSerializer.new(@version).serializable_hash[:data][:attributes]
    )
  end

  # GET /v1/admin/client/versions/:id/user_versions
  def read_user_versions
    records = @version.user_versions.includes(:user)
    records = sort(records, columns: SortConstants::Columns::USER_VERSION, default_column: :last_seen_at)
    pagy, page_records = pagy(records)

    render_json_response(
      status_code: 200,
      message: user_version_message(MessageService::UserVersion::FETCHED),
      data: Client::UserVersionAdminSerializer.paginated(page_records, pagy),
      pagy: pagy
    )
  end

  private

  def filter_params
    params.permit(:discarded, :status)
  end

  def set_active_version
    @version = Client::Version.find(params.permit(:id)[:id])
  end

  def set_version_including_discarded
    @version = Client::Version.with_discarded.find(params.permit(:id)[:id])
  end

  def version_params
    permitted = params.require(:version).permit(
      :number,
      :title,
      :description,
      :is_force_update,
      :status,
      :ios_build_number,
      :android_build_number,
      metadata: {}
    )

    %i[ios_build_number android_build_number].each do |key|
      permitted[key] = nil if permitted[key].blank?
    end

    permitted
  end

  def render_not_found
    render_json_response(
      status_code: 404,
      message: version_message(MessageService::Version::NOT_FOUND),
      error: version_message(MessageService::Version::NOT_FOUND)
    )
  end

  def version_message(key, **options)
    MessageService::Version.t(key, **options)
  end

  def user_version_message(key, **options)
    MessageService::UserVersion.t(key, **options)
  end
end
