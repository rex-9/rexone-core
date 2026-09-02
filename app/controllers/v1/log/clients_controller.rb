# app/controllers/v1/log/clients_controller.rb
class V1::Log::ClientsController < V1::ApplicationController
  skip_before_action :authenticate_user!, only: [ :create ]
  before_action :set_log_client, only: [ :show, :update_resolve, :update_unresolve, :discard ]
  before_action :set_log_client_including_discarded, only: [ :undiscard, :destroy ]

  # POST /log/clients
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
      log_client.assign_attributes(log_client_params)
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

  # GET /log/clients
  def index
    logs = Log::Client.all
    logs = apply_filters(logs)
    logs = sort(logs, columns: SortConstants::Columns::CLIENT_LOG)

    pagy, records = pagy(logs)
    serialized = Log::ClientSerializer.paginated(records, pagy)

    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::FETCHED),
      data: serialized,
      pagy: pagy
    )
  end

  # GET /log/clients/:id
  def show
    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::FETCHED_ONE),
      data: Log::ClientSerializer.new(@log_client).serializable_hash[:data]
    )
  end

  # PATCH /log/clients/:id/resolve
  def update_resolve
    @log_client.resolve!(resolved_by: current_user)

    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::RESOLVED),
      data: Log::ClientSerializer.new(@log_client).serializable_hash[:data]
    )
  end

  # PATCH /log/clients/:id/unresolve
  def update_unresolve
    @log_client.unresolve!

    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::UNRESOLVED),
      data: Log::ClientSerializer.new(@log_client).serializable_hash[:data]
    )
  end

  # POST /log/clients/:id/discard
  def discard
    @log_client.discard!

    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::DELETED)
    )
  end

  # POST /log/clients/:id/undiscard
  def undiscard
    @log_client.undiscard!

    render_json_response(
      status_code: 200,
      message: log_message(MessageService::Log::RESOLVED),
      data: Log::ClientSerializer.new(@log_client).serializable_hash[:data]
    )
  end

  # DELETE /log/clients/:id
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
    @log_client = Log::Client.find(params[:id])
  end

  def set_log_client_including_discarded
    @log_client = Log::Client.with_discarded.find(params[:id])
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
    conditions = {
      message: params[:log][:message],
      severity: params[:log][:severity] || "error",
      platform: params[:log][:platform],
      environment: params[:log][:environment],
      os: params[:log][:os],
      os_version: params[:log][:os_version],
      browser: params[:log][:browser],
      url: params[:log][:url],
      method: params[:log][:method]
    }.compact

    Log::Client.find_or_initialize_by(conditions)
  end

  def apply_filters(logs)
    logs = if params[:discarded].to_s == "true"
      logs.with_discarded.discarded
    else
      logs.kept
    end
    logs = logs.by_severity(params[:severity]) if params[:severity].present?
    logs = logs.by_platform(params[:platform]) if params[:platform].present?
    logs = logs.by_environment(params[:environment]) if params[:environment].present?
    logs = logs.unresolved if params[:unresolved] == "true"
    logs = logs.resolved if params[:resolved] == "true"
    logs = logs.with_storage_issues if params[:storage_issues] == "true"
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
