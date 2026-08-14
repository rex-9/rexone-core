# app/controllers/v1/log/clients_controller.rb
class V1::Log::ClientsController < V1::ApplicationController
  skip_before_action :authenticate_user!, only: [ :create ] # Allow public errors
  before_action :set_log_client, only: [ :show, :update_resolve, :update_unresolve ]

  # POST /log/clients
  def create
  log_client = Log::Client.new(log_client_params)

  # Attach user if authenticated
  log_client.user = current_user if current_user.present?

  # Set default values
  log_client.severity ||= "error"
  log_client.request_id ||= request.request_id
  log_client.url ||= request.referer || request.url
  log_client.method ||= request.method

    if log_client.save
      render_json_response(
        status_code: 201,
        message: "Client log created successfully",
        data: { id: log_client.id }
      )
    else
      render_json_response(
        status_code: 422,
        message: "Failed to create client log",
        error: log_client.errors.full_messages.to_sentence
      )
    end
  end

  # GET /log/clients
  def index
    authorize! :read, Log::Client

    logs = Log::Client.all.order(created_at: :desc)

    # Apply filters
    logs = logs.by_severity(params[:severity]) if params[:severity].present?
    logs = logs.by_platform(params[:platform]) if params[:platform].present?
    logs = logs.by_environment(params[:environment]) if params[:environment].present?
    logs = logs.unresolved if params[:unresolved] == "true"
    logs = logs.resolved if params[:resolved] == "true"
    logs = logs.with_storage_issues if params[:storage_issues] == "true"

    pagy, records = pagy(:offset, logs, limit: params[:limit])
    serialized = Log::ClientSerializer.paginated(records, pagy)

    render_json_response(
      status_code: 200,
      message: "Client logs fetched successfully",
      data: serialized,
      pagy: pagy
    )
  end

  # GET /log/clients/:id
  def show
    authorize! :read, Log::Client
    render_json_response(
      status_code: 200,
      message: "Client log fetched successfully",
      data: Log::ClientSerializer.new(@log_client).serializable_hash[:data]
    )
  end

  # PATCH /log/clients/:id/resolve
  def update_resolve
    authorize! :update, Log::Client
    @log_client.resolve!(resolved_by: current_user)

    render_json_response(
      status_code: 200,
      message: "Client log marked as resolved",
      data: Log::ClientSerializer.new(@log_client).serializable_hash[:data]
    )
  end

  # PATCH /log/clients/:id/unresolve
  def update_unresolve
    authorize! :update, Log::Client
    @log_client.unresolve!

    render_json_response(
      status_code: 200,
      message: "Client log marked as unresolved",
      data: Log::ClientSerializer.new(@log_client).serializable_hash[:data]
    )
  end

  # DELETE /log/clients/:id (hard delete)
  def destroy
    authorize! :destroy, Log::Client
    @log_client.destroy!

    render_json_response(
      status_code: 200,
      message: "Client log deleted permanently"
    )
  end

  private

  def set_log_client
    @log_client = Log::Client.find(params[:id])
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

  def detect_platform
    user_agent = request.user_agent.to_s.downcase

    return "ios" if user_agent.include?("ios") || user_agent.include?("iphone") || user_agent.include?("ipad")
    return "android" if user_agent.include?("android")
    "web"
  end

  def detect_environment
    params[:environment].presence || Rails.env
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
