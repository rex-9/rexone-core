class V1::Admin::Client::UserVersionsController < V1::ApplicationController
  before_action :super_admin_required!

  # GET /v1/admin/client/versions/user_versions
  def index
    filters = filter_params
    records = Client::UserVersion.includes(:user)
    records = records.where(platform: filters[:platform]) if filters[:platform].present?
    records = sort(records, columns: SortConstants::Columns::USER_VERSION, default_column: :last_seen_at)
    pagy, page_records = pagy(records)

    render_json_response(
      status_code: 200,
      message: user_version_message(MessageService::UserVersion::FETCHED),
      **Client::UserVersionAdminSerializer.paginated(page_records, pagy)
    )
  end

  private

  def filter_params
    params.permit(:platform)
  end

  def user_version_message(key, **options)
    MessageService::UserVersion.t(key, **options)
  end
end
