require "rails_helper"

RSpec.describe "V1 Admin AI Profiles API", type: :request do
  let(:admin) { create(:user) }
  let(:token) { jwt_for(admin) }
  let(:headers) { authorization_headers(token) }

  before do
    allow(CacheService).to receive(:read).and_return(token)
    allow(CacheService).to receive(:write)
    grant_admin_role(admin)
    grant_admin_permissions(admin, IamConstants::Resource::AI_PROFILES, :read, :create, :update)
  end

  describe "Authorization & Permissions" do
    let(:unprivileged_user) { create(:user) }
    let(:unprivileged_token) { jwt_for(unprivileged_user) }
    let(:unprivileged_headers) { authorization_headers(unprivileged_token) }

    before do
      allow(CacheService).to receive(:read).with(any_args).and_return(unprivileged_token)
    end

    it "requires authentication" do
      get "/v1/admin/ai/profiles"
      expect(response).to have_http_status(:unauthorized)
    end

    it "forbids non-admin users even with permission" do
      grant_permissions(unprivileged_user, IamConstants::Resource::AI_PROFILES, :read)
      get "/v1/admin/ai/profiles", headers: unprivileged_headers
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids admin users without ai_profiles:read permission" do
      admin_without_perm = create(:user)
      admin_token = jwt_for(admin_without_perm)
      allow(CacheService).to receive(:read).with(any_args).and_return(admin_token)
      grant_admin_role(admin_without_perm)

      get "/v1/admin/ai/profiles", headers: authorization_headers(admin_token)
      expect(response).to have_http_status(:forbidden)
    end

    it "forbids admin users from creating without ai_profiles:create permission" do
      admin_read_only = create(:user)
      admin_token = jwt_for(admin_read_only)
      allow(CacheService).to receive(:read).with(any_args).and_return(admin_token)
      read_only_role = Iam::Role.create!(name: "ai_profiles_readonly_create_admin")
      perm = Iam::Permission.find_or_create_by!(action: "read", resource: IamConstants::Resource::AI_PROFILES)
      Iam::RolePermission.create!(role: read_only_role, permission: perm)
      Iam::UserRole.create!(user: admin_read_only, role: read_only_role)

      post "/v1/admin/ai/profiles",
           params: { profile: { key: "new_agent", name: "New Agent" } },
           headers: authorization_headers(admin_token)

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids admin users from updating without ai_profiles:update permission" do
      admin_read_only = create(:user)
      admin_token = jwt_for(admin_read_only)
      allow(CacheService).to receive(:read).with(any_args).and_return(admin_token)
      read_only_role = Iam::Role.create!(name: "ai_profiles_readonly_admin")
      perm = Iam::Permission.find_or_create_by!(action: "read", resource: IamConstants::Resource::AI_PROFILES)
      Iam::RolePermission.create!(role: read_only_role, permission: perm)
      Iam::UserRole.create!(user: admin_read_only, role: read_only_role)

      profile = create(:ai_profile, key: "chat_default")

      patch "/v1/admin/ai/profiles/#{profile.id}",
            params: { profile: { temperature: 0.5 } },
            headers: authorization_headers(admin_token)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /v1/admin/ai/profiles" do
    it "returns list of AI profiles" do
      create(:ai_profile, key: AiConstants::ProfileKey::CHAT_DEFAULT, name: "Default Chat")
      create(:ai_profile, key: AiConstants::ProfileKey::ANALYZE, name: "Data Analyzer")

      get "/v1/admin/ai/profiles", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.size).to be >= 2
    end

    it "filters profiles by provider and model" do
      create(:ai_profile, key: "deepseek_prof", provider: "deepseek", model: "deepseek-chat")
      create(:ai_profile, key: "gemini_prof", provider: "gemini", model: "gemini-2.5-flash")

      get "/v1/admin/ai/profiles", params: { provider: "gemini", model: "gemini-2.5-flash" }, headers: headers

      expect(response).to have_http_status(:ok)
      keys = response_data.map { |r| r.dig("attributes", "key") }
      expect(keys).to include("gemini_prof")
      expect(keys).not_to include("deepseek_prof")
    end

    it "sorts profiles by key ascending" do
      create(:ai_profile, key: "aaa_profile", name: "Alpha")
      create(:ai_profile, key: "zzz_profile", name: "Omega")

      get "/v1/admin/ai/profiles", params: { sort_by: "key", sort_order: "asc" }, headers: headers

      expect(response).to have_http_status(:ok)
      keys = response_data.map { |r| r.dig("attributes", "key") }
      expect(keys.index("aaa_profile")).to be < keys.index("zzz_profile")
    end
  end

  describe "GET /v1/admin/ai/profiles/:id" do
    it "finds profile by key" do
      create(:ai_profile, key: AiConstants::ProfileKey::CHAT_DEFAULT, name: "Default Chat")

      get "/v1/admin/ai/profiles/#{AiConstants::ProfileKey::CHAT_DEFAULT}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "name")).to eq("Default Chat")
    end

    it "finds profile by UUID" do
      profile = create(:ai_profile, key: AiConstants::ProfileKey::ANALYZE, name: "Data Analyzer")

      get "/v1/admin/ai/profiles/#{profile.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "key")).to eq(AiConstants::ProfileKey::ANALYZE)
    end

    it "returns 404 when profile is not found" do
      get "/v1/admin/ai/profiles/nonexistent_profile_key", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /v1/admin/ai/profiles" do
    it "creates a new AI profile" do
      post "/v1/admin/ai/profiles",
           params: {
             profile: {
               key: "customer_support",
               name: "Customer Support Agent",
               model: "deepseek-chat",
               temperature: 0.5,
               max_output_tokens: 1500,
               system_prompt: "You are a helpful customer support agent."
             }
           },
           headers: headers

      expect(response).to have_http_status(:created)
      expect(response_data.dig("attributes", "key")).to eq("customer_support")
      expect(response_data.dig("attributes", "name")).to eq("Customer Support Agent")
      expect(Ai::Profile.find_by(key: "customer_support")).to be_present
    end

    it "returns 422 when validation fails" do
      post "/v1/admin/ai/profiles",
           params: { profile: { key: "Invalid Key!", name: "" } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /v1/admin/ai/profiles/:id" do
    it "updates profile settings and model configuration" do
      profile = create(:ai_profile, key: "chat_default", temperature: 0.7)

      patch "/v1/admin/ai/profiles/#{profile.id}",
            params: { profile: { temperature: 0.2, model: "deepseek-coder" } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(response_data.dig("attributes", "temperature")).to eq(0.2)
      expect(profile.reload.model).to eq("deepseek-coder")
    end
  end
end
