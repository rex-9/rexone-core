require "rails_helper"

RSpec.describe "Admin notification broadcasts", type: :request do
  let(:user) { create(:user) }
  let(:recipient) { create(:user) }
  let(:audience_role) { create(:role, name: "teacher") }
  let!(:recipient_role) { create(:user_role, user: recipient, role: audience_role) }
  let(:token) { jwt_for(user) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
  end

  it "requires authentication" do
    post "/v1/admin/notifications", params: valid_params

    expect(response).to have_http_status(:unauthorized)
    expect(Notification::DispatchJob).not_to have_been_enqueued
  end

  it "lists only admin notification events" do
    grant_admin_notification_permission(action: "read")

    get "/v1/admin/notifications/templates", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response_data).to contain_exactly(
      hash_including("event" => "general_announcement", "admin_available" => true),
      hash_including("event" => "maintenance_notice", "admin_available" => true),
      hash_including("event" => "feature_update", "admin_available" => true)
    )
  end

  it "requires an admin role even with notification permission" do
    grant_notification_permission

    post "/v1/admin/notifications", params: valid_params, headers: headers

    expect(response).to have_http_status(:forbidden)
    expect(Notification::DispatchJob).not_to have_been_enqueued
  end

  it "requires notification creation permission from an admin" do
    create(:user_role, user: user, role: create(:role, name: "admin"))

    post "/v1/admin/notifications", params: valid_params, headers: headers

    expect(response).to have_http_status(:forbidden)
    expect(Notification::DispatchJob).not_to have_been_enqueued
  end

  it "queues selected roles and channels for dispatch" do
    grant_admin_notification_permission

    post "/v1/admin/notifications", params: valid_params, headers: headers

    expect(response).to have_http_status(:accepted)
    expect(response_data).to include(
      "audience" => "roles",
      "recipient_count" => 1,
      "channels" => %w[socket email]
    )
    expect(Notification::DispatchJob).to have_been_enqueued.with(
      audience: { type: "roles", role_ids: [ audience_role.id ] },
      channels: %w[socket email],
      event: "general_announcement",
      locale: "en"
    )
  end

  it "supports an all-user audience without serializing every recipient" do
    grant_admin_notification_permission

    post "/v1/admin/notifications",
         params: valid_params.merge(audience: { type: "all" }, channels: [ "push" ]),
         headers: headers

    expect(response).to have_http_status(:accepted)
    expect(response_data).to include("audience" => "all", "recipient_count" => 2)
    expect(Notification::DispatchJob).to have_been_enqueued.with(
      hash_including(audience: { type: "all" }, channels: [ "push" ])
    )
  end

  it "queues selected users for dispatch" do
    grant_admin_notification_permission

    post "/v1/admin/notifications",
         params: valid_params.merge(audience: { type: "users", user_ids: [ recipient.id ] }),
         headers: headers

    expect(response).to have_http_status(:accepted)
    expect(response_data).to include("audience" => "users", "recipient_count" => 1)
    expect(Notification::DispatchJob).to have_been_enqueued.with(
      hash_including(audience: { type: "users", user_ids: [ recipient.id ] })
    )
  end

  it "localizes success messages from X-Locale" do
    grant_admin_notification_permission

    post "/v1/admin/notifications",
         params: valid_params,
         headers: headers.merge("X-Locale" => "my")

    expect(response).to have_http_status(:accepted)
    expect(response_status["message"]).to eq(I18n.t("notification.queued", locale: :my))
  end

  it "localizes validation errors from Accept-Language" do
    grant_admin_notification_permission

    post "/v1/admin/notifications",
         params: valid_params.except(:event),
         headers: headers.merge("Accept-Language" => "my-MM,my;q=0.9,en;q=0.8")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["message"]).to eq(I18n.t("notification.invalid_request", locale: :my))
    expect(response_status["error"]).to eq(I18n.t("notification.event_required", locale: :my))
  end

  it "falls back to English for unsupported locales" do
    grant_admin_notification_permission

    post "/v1/admin/notifications",
         params: valid_params.merge(event: "payment_failed"),
         headers: headers.merge("X-Locale" => "es")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response_status["message"]).to eq(I18n.t("notification.invalid_request", locale: :en))
    expect(response_status["error"]).to eq(I18n.t("notification.invalid_event", locale: :en))
  end

  it "rejects missing content, unsupported channels, and incomplete audiences" do
    grant_admin_notification_permission

    [
      valid_params.except(:event),
      valid_params.merge(event: "payment_failed"),
      valid_params.merge(channels: []),
      valid_params.merge(channels: [ "carrier_pigeon" ]),
      valid_params.merge(audience: { type: "users", user_ids: [] }),
      valid_params.merge(audience: { type: "roles", role_ids: [] }),
      valid_params.merge(audience: { type: "roles", role_ids: [ SecureRandom.uuid ] }),
      valid_params.merge(audience: { type: "segment" })
    ].each do |invalid_params|
      post "/v1/admin/notifications", params: invalid_params, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    expect(Notification::DispatchJob).not_to have_been_enqueued
  end

  it "returns service unavailable when dispatch cannot be queued" do
    grant_admin_notification_permission
    allow(Notification::DispatchJob).to receive(:perform_later)
      .and_raise(SolidQueue::Job::EnqueueError.new("queue unavailable"))

    post "/v1/admin/notifications", params: valid_params, headers: headers

    expect(response).to have_http_status(:service_unavailable)
  end

  def valid_params
    {
      event: "general_announcement",
      audience: { type: "roles", role_ids: [ audience_role.id ] },
      channels: %w[socket email]
    }
  end

  def grant_notification_permission
    role = create(:role, name: "notification_manager")
    permission = create(:permission, action: "create", resource: "notifications")
    create(:role_permission, role: role, permission: permission)
    create(:user_role, user: user, role: role)
  end

  def grant_admin_notification_permission(action: "create")
    role = create(:role, name: "admin")
    permission = create(:permission, action: action, resource: "notifications")
    create(:role_permission, role: role, permission: permission)
    create(:user_role, user: user, role: role)
  end
end
