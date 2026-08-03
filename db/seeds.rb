# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# db/seeds.rb
# ===== IAM PERMISSIONS =====
puts "🌱 Seeding IAM permissions..."

permissions = [
  # Users
  { name: "manage_users", action: "read", resource: "users" },
  { name: "manage_users", action: "create", resource: "users" },
  { name: "manage_users", action: "update", resource: "users" },
  { name: "manage_users", action: "delete", resource: "users" },

  # Roles
  { name: "manage_roles", action: "read", resource: "roles" },
  { name: "manage_roles", action: "create", resource: "roles" },
  { name: "manage_roles", action: "update", resource: "roles" },
  { name: "manage_roles", action: "delete", resource: "roles" },

  # Permissions
  { name: "manage_permissions", action: "read", resource: "permissions" },
  { name: "manage_permissions", action: "create", resource: "permissions" },
  { name: "manage_permissions", action: "update", resource: "permissions" },
  { name: "manage_permissions", action: "delete", resource: "permissions" },

  # Products
  { name: "manage_products", action: "read", resource: "products" },
  { name: "manage_products", action: "create", resource: "products" },
  { name: "manage_products", action: "update", resource: "products" },
  { name: "manage_products", action: "delete", resource: "products" },

  # Payments
  { name: "manage_payments", action: "read", resource: "payments" },
  { name: "manage_payments", action: "create", resource: "payments" },
  { name: "manage_payments", action: "update", resource: "payments" },
  { name: "manage_payments", action: "delete", resource: "payments" },

  # Chat
  { name: "manage_chat", action: "read", resource: "chat" },
  { name: "manage_chat", action: "create", resource: "chat" },
  { name: "manage_chat", action: "update", resource: "chat" },
  { name: "manage_chat", action: "delete", resource: "chat" },

  # Assets
  { name: "manage_assets", action: "read", resource: "assets" },
  { name: "manage_assets", action: "create", resource: "assets" },
  { name: "manage_assets", action: "update", resource: "assets" },
  { name: "manage_assets", action: "delete", resource: "assets" },

  # Dashboard
  { name: "view_dashboard", action: "read", resource: "dashboard" }
]

permissions.each do |p|
  Iam::Permission.find_or_create_by!(name: p[:name]) do |perm|
    perm.action = p[:action]
    perm.resource = p[:resource]
  end
end

puts "✅ #{Iam::Permission.count} permissions created"

# ===== IAM ROLES =====
puts "🌱 Seeding IAM roles..."

# Super Admin - all permissions
super_admin = Iam::Role.find_or_create_by!(name: "super_admin") do |r|
  r.description = "Full system access"
  r.system = true
end

# Admin - all except role management
admin = Iam::Role.find_or_create_by!(name: "admin") do |r|
  r.description = "Admin with limited role management"
  r.system = true
end

# Manager - read/update users, read/update chat
manager = Iam::Role.find_or_create_by!(name: "manager") do |r|
  r.description = "Manage users and chat"
  r.system = true
end

# Support - read and reply to chat
support = Iam::Role.find_or_create_by!(name: "support") do |r|
  r.description = "Support staff"
  r.system = true
end

# Viewer - read-only access
viewer = Iam::Role.find_or_create_by!(name: "viewer") do |r|
  r.description = "Read-only access"
  r.system = true
end

puts "✅ #{Iam::Role.count} roles created"

# ===== ASSIGN PERMISSIONS TO ROLES =====
puts "🌱 Assigning permissions to roles..."

# Super Admin: all permissions
Iam::Permission.all.each do |perm|
  Iam::RolePermission.find_or_create_by!(role: super_admin, permission: perm)
end

# Admin: all except role management
Iam::Permission.where.not(resource: "roles").each do |perm|
  Iam::RolePermission.find_or_create_by!(role: admin, permission: perm)
end

# Manager: read/update users, read/update chat, view dashboard, create users
%w[users chat dashboard].each do |resource|
  Iam::Permission.where(resource: resource, action: [ "read", "update" ]).each do |perm|
    Iam::RolePermission.find_or_create_by!(role: manager, permission: perm)
  end
end
Iam::Permission.find_by(resource: "users", action: "create")&.tap do |perm|
  Iam::RolePermission.find_or_create_by!(role: manager, permission: perm)
end

# Support: read/create/update chat, read users
Iam::Permission.where(resource: "chat", action: [ "read", "create", "update" ]).each do |perm|
  Iam::RolePermission.find_or_create_by!(role: support, permission: perm)
end
Iam::Permission.find_by(resource: "users", action: "read")&.tap do |perm|
  Iam::RolePermission.find_or_create_by!(role: support, permission: perm)
end

# Viewer: read payments, read products, read dashboard
%w[payments products dashboard].each do |resource|
  Iam::Permission.find_by(resource: resource, action: "read")&.tap do |perm|
    Iam::RolePermission.find_or_create_by!(role: viewer, permission: perm)
  end
end

puts "✅ #{Iam::RolePermission.count} role-permission assignments created"

# ===== DEFAULT ADMIN USER =====
puts "🌱 Creating default admin users..."

super_admin_user = User.find_or_create_by!(email: "super@admin.com") do |u|
  u.username = "super_admin"
  u.name = "Super Admin User"
  u.password = "123456"
  u.password_confirmation = "123456"
  u.confirmed_at = Time.current
end

Iam::UserRole.find_or_create_by!(user: super_admin_user, role: super_admin)

puts "✅ Super Admin user created: super@admin.com / 123456"

admin_user = User.find_or_create_by!(email: "just@admin.com") do |u|
  u.username = "just_admin"
  u.name = "Just Admin User"
  u.password = "123456"
  u.password_confirmation = "123456"
  u.confirmed_at = Time.current
end

Iam::UserRole.find_or_create_by!(user: admin_user, role: admin)

puts "✅ Admin user created: just@admin.com / 123456"
puts "✅ Seeding complete!"
