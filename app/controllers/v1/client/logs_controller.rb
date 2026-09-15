# app/controllers/v1/client/logs_controller.rb
class V1::Client::LogsController < V1::ApplicationController
  skip_before_action :authenticate_user!, only: [ :create ]
  before_action :set_log_client, only: [ :show, :update_resolve, :update_unresolve, :discard ]
  before_action :set_log_client_including_discarded, only: [ :undiscard, :destroy ]

  # POST /v1/client/logs
  def create
    log_client = find_or_initialize_log

    if log_client.persisted?
      # Increment occurrence count and update timestamp
      log_client.increment!(:occurrence_count)
      log_client.touch(:last_occurred_at)

      render_json_response(
        status_code: 200,
        message: log_message(MessageService::Log::OCCURRENCE_RECORDED),
        data: { id: log_client.id, occurrence_count: log_client.occurrence_count }
      )
    else
      # New log - assign attributes and save
      log_client.assign_attributes(log_client_params.except(:app_version))
      log_client.version_id = Client::Version.lookup_by_number(log_client_params[:app_version])&.id
      log_client.user = current_user if current_user.present?
      log_client.severity ||= "error"
      log_client.request_id ||= request.request_id
      log_client.url ||= request.referer || request.url
      log_client.method ||= request.method

      if log_client.save
        render_json_response(
          status_code: 201,
          message: log_message(MessageService::Log::CREATED),
          data: { id: log_client.id }
        )
      else
        render_json_response(
          status_code: 422,
          message: log_message(MessageService::Log::CREATE_FAILED),
          error: log_client.errors.full_messages.to_sentence
        )
      end
    end
  end

  # GET /v1/client/logs
  def index
    logs = Client::Log.all
    logs = apply_filters(logs)
    logs = sort(logs, columns: SortConstants::Columns::CLIENT_LOG)

    pagy, records = pagy(logs)
    serialized = Client::LogSerializer.paginated(records, pagy)

    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::FETCHED),
      data: serialized,
      pagy: pagy
    )
  end

  # GET /v1/client/logs/:id
  def show
    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::FETCHED_ONE),
      data: Client::LogSerializer.new(@log_client).serializable_hash[:data]
    )
  end

  # PUT /v1/client/logs/:id/resolve
  def update_resolve
    @log_client.resolve!(resolved_by: current_user)

    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::RESOLVED),
      data: Client::LogSerializer.new(@log_client).serializable_hash[:data]
    )
  end

  # PUT /v1/client/logs/:id/unresolve
  def update_unresolve
    @log_client.unresolve!

    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::UNRESOLVED),
      data: Client::LogSerializer.new(@log_client).serializable_hash[:data]
    )
  end

  # POST /v1/client/logs/:id/discard
  def discard
    @log_client.discard!

    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::DELETED)
    )
  end

  # POST /v1/client/logs/:id/undiscard
  def undiscard
    @log_client.undiscard!

    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::RESOLVED),
      data: Client::LogSerializer.new(@log_client).serializable_hash[:data]
    )
  end

  # DELETE /v1/client/logs/:id
  def destroy
    @log_client.destroy!

    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::DELETED)
    )
  end

  private

  def log_message(key, **options)
    MessageService::Log.t(key, **options)
  end

  def set_log_client
    @log_client = Client::Log.find(params.permit(:id)[:id])
  end

  def set_log_client_including_discarded
    @log_client = Client::Log.with_discarded.find(params.permit(:id)[:id])
  end

  def log_client_params
    params.require(:log).permit(
      :message, :severity, :platform, :environment,
      :app_version, :browser, :user_agent, :os, :os_version, :device,
      :url, :method,
      context: {},
      stack_trace: [],
      local_storage_keys: [],
      session_storage_keys: [],
      cookies: {}
    )
  end

  def find_or_initialize_log
    attrs = log_client_params
    conditions = {
      message: attrs[:message],
      severity: attrs[:severity].presence || "error",
      platform: attrs[:platform],
      environment: attrs[:environment],
      os: attrs[:os],
      os_version: attrs[:os_version],
      browser: attrs[:browser],
      url: attrs[:url],
      method: attrs[:method]
    }.compact

    Client::Log.find_or_initialize_by(conditions)
  end

  def filter_params
    params.permit(:discarded, :severity, :platform, :environment, :unresolved, :resolved, :storage_issues)
  end

  def apply_filters(logs)
    filters = filter_params
    logs = if filters[:discarded].to_s == "true"
      logs.with_discarded.discarded
    else
      logs.kept
    end
    logs = logs.by_severity(filters[:severity]) if filters[:severity].present?
    logs = logs.by_platform(filters[:platform]) if filters[:platform].present?
    logs = logs.by_environment(filters[:environment]) if filters[:environment].present?
    logs = logs.unresolved if filters[:unresolved] == "true"
    logs = logs.resolved if filters[:resolved] == "true"
    logs = logs.with_storage_issues if filters[:storage_issues] == "true"
    logs
  end
end

# Payload Example
# {
#   "log": {
#     "message": "Failed to fetch user data: Network request failed", # required
#     "severity": "error", # required
#     "context": {
#       "component": "UserDashboard",
#       "action": "loadUserProfile",
#       "userId": "usr_123",
#       "attempt": 3,
#       "endpoint": "/api/v1/users/current"
#     },
#     "stack_trace": [
#       "Error: Network request failed",
#       "at fetchUser (UserService.js:23:15)",
#       "at UserDashboard.loadProfile (UserDashboard.js:45:10)",
#       "at UserDashboard.componentDidMount (UserDashboard.js:12:8)"
#     ],
#     "local_storage_keys": [ "auth_token", "user_preferences" ],
#     "session_storage_keys": [ "checkout_flow" ],
#     "cookies": {
#       "session_id": "abc123",
#       "csrf_token": "xyz789"
#     },
#     "platform": "web",
#     "environment": "production",
#     "app_version": "2.1.3",
#     "browser": "Chrome 120.0.6099.109",
#     "os": "macOS",
#     "os_version": "10.15.0",
#     "device": "Mac",
#     "user_agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36...",
#     "url": "https://yourapp.com/dashboard",
#     "method": "GET"
#   }
# }
