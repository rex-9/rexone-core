module AuthHelpers
  def json_body
    JSON.parse(response.body)
  end

  def response_data
    json_body.fetch("data", {})
  end

  def response_meta
    json_body.fetch("meta", {})
  end

  def response_status
    json_body.fetch("status")
  end

  def jwt_for(user)
    AppConfig::JWT_TOKEN.call(user)
  end

  def authorization_headers(token, platform: "web")
    { "Authorization" => "Bearer #{token}", "X-Platform" => platform, "ACCEPT" => "application/json" }
  end

  def grant_permissions(user, resource, *actions, admin: false)
    role_name = admin ? "#{resource}_admin" : "#{resource}_#{actions.flatten.join('_')}_role"
    role = Iam::Role.find_or_create_by!(name: role_name)
    actions.flatten.each do |action|
      perm = Iam::Permission.find_or_create_by!(action: action.to_s, resource: resource.to_s)
      Iam::RolePermission.find_or_create_by!(role: role, permission: perm)
    end
    Iam::UserRole.find_or_create_by!(user: user, role: role)
  end

  def grant_admin_permissions(user, resource, *actions)
    grant_permissions(user, resource, *actions, admin: true)
  end

  def grant_admin_role(user)
    role = Iam::Role.find_or_create_by!(name: "admin")
    Iam::UserRole.find_or_create_by!(user: user, role: role)
  end

  def grant_super_admin_role(user)
    role = Iam::Role.find_or_create_by!(name: "super_admin")
    Iam::UserRole.find_or_create_by!(user: user, role: role)
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
