# db/seeds.rb

# ===== IAM PERMISSIONS =====
puts "🌱 Seeding IAM permissions..."

# These are CONTROLLER names (what the Authorization concern uses)
RESOURCES = %w[
  users
  roles
  permissions
  products
  payments
  subscriptions
  transactions
  accesses
  chat
  assets
  dashboard
  ai
].freeze

ACTIONS = %w[read create update delete].freeze

# Clear existing data in the correct order
puts "🗑️  Clearing existing IAM data..."
Iam::RolePermission.delete_all
Iam::UserRole.delete_all
Iam::Role.delete_all
Iam::Permission.delete_all

puts "✅ IAM data cleared"

# Create all permissions (4 actions × 12 resources = 48 permissions)
puts "🌱 Creating all permissions..."
permissions = []

RESOURCES.each do |resource|
  ACTIONS.each do |action|
    permissions << {
      name: "#{action}_#{resource}",
      action: action,
      resource: resource
    }
  end
end

permissions.each do |p|
  Iam::Permission.create!(p)
end

puts "✅ #{Iam::Permission.count} permissions created"

# ===== IAM ROLES =====
puts "🌱 Seeding IAM roles..."

super_admin = Iam::Role.create!(
  name: "super_admin",
  description: "Full system access",
  system: true
)

admin = Iam::Role.create!(
  name: "admin",
  description: "Admin with limited role management",
  system: true
)

manager = Iam::Role.create!(
  name: "manager",
  description: "Manage users and chat",
  system: true
)

support = Iam::Role.create!(
  name: "support",
  description: "Support staff",
  system: true
)

viewer = Iam::Role.create!(
  name: "viewer",
  description: "Read-only access",
  system: true
)

puts "✅ #{Iam::Role.count} roles created"

# ===== ASSIGN PERMISSIONS TO ROLES =====
puts "🌱 Assigning permissions to roles..."

# Super Admin: ALL permissions
Iam::Permission.all.each do |perm|
  Iam::RolePermission.create!(role: super_admin, permission: perm)
end

# Admin: ALL permissions EXCEPT role management
Iam::Permission.where.not(resource: "roles").each do |perm|
  Iam::RolePermission.create!(role: admin, permission: perm)
end

# Manager: read/update users, read/update chat, view dashboard, create users
%w[users chat].each do |resource|
  Iam::Permission.where(resource: resource, action: %w[read update]).each do |perm|
    Iam::RolePermission.create!(role: manager, permission: perm)
  end
end
Iam::Permission.find_by(resource: "users", action: "create")&.tap do |perm|
  Iam::RolePermission.create!(role: manager, permission: perm)
end
Iam::Permission.find_by(resource: "dashboard", action: "read")&.tap do |perm|
  Iam::RolePermission.create!(role: manager, permission: perm)
end

# Support: read/create/update chat, read users
Iam::Permission.where(resource: "chat", action: %w[read create update]).each do |perm|
  Iam::RolePermission.create!(role: support, permission: perm)
end
Iam::Permission.find_by(resource: "users", action: "read")&.tap do |perm|
  Iam::RolePermission.create!(role: support, permission: perm)
end

# Viewer: read payments, subscriptions, transactions, products, dashboard
%w[payments subscriptions transactions products dashboard].each do |resource|
  Iam::Permission.find_by(resource: resource, action: "read")&.tap do |perm|
    Iam::RolePermission.create!(role: viewer, permission: perm)
  end
end

puts "✅ #{Iam::RolePermission.count} role-permission assignments created"

# ===== DEFAULT ADMIN USER =====
puts "🌱 Creating default admin users..."

User.where(email: [ "super@admin.com", "just@admin.com" ]).destroy_all

super_admin_user = User.create!(
  email: "super@admin.com",
  username: "super_admin",
  name: "Super Admin User",
  password: "123456",
  password_confirmation: "123456",
  confirmed_at: Time.current
)

Iam::UserRole.create!(user: super_admin_user, role: super_admin)

puts "✅ Super Admin user created: super@admin.com / 123456"

admin_user = User.create!(
  email: "just@admin.com",
  username: "just_admin",
  name: "Just Admin User",
  password: "123456",
  password_confirmation: "123456",
  confirmed_at: Time.current
)

Iam::UserRole.create!(user: admin_user, role: admin)

puts "✅ Admin user created: just@admin.com / 123456"
puts "✅ Seeding complete!"
