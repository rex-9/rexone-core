# ===== IAM PERMISSIONS =====
puts "🌱 Seeding IAM permissions..."

# Clear existing data in the correct order
puts "🗑️  Clearing existing IAM data..."
Iam::RolePermission.delete_all
Iam::UserRole.delete_all
Iam::Role.delete_all
Iam::Permission.delete_all

puts "✅ IAM data cleared"

# Seed all permissions
puts "🌱 Creating all permissions..."

Iam::Permission::RESOURCES.each do |resource|
  Iam::Permission::ACTIONS.each do |action|
    Iam::Permission.find_or_create_by!(action: action, resource: resource) do |perm|
      perm.name = "#{action}_#{resource}"
    end
  end
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

# Default user role - assigned to all new users
default_user = Iam::Role.create!(
  name: "user",
  description: "Default user role for all registered users",
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

# Default User Role Permissions
puts "🌱 Assigning permissions to default user role..."

user_permissions = [
  # Logs - create only
  { resource: "clients", actions: [ "create" ] },
  # Products - read only
  { resource: "products", actions: [ "read" ] },
  # Payments - create only
  { resource: "payments", actions: [ "create" ] },
  # Subscriptions - read only
  { resource: "subscriptions", actions: [ "read", "create" ] },
  # Transactions - read only
  { resource: "transactions", actions: [ "read" ] },
  # Accesses - read only
  { resource: "accesses", actions: [ "read" ] },
  # Assets - full CRUD
  { resource: "assets", actions: [ "read", "create", "update", "delete" ] },
  # Users - full CRUD
  { resource: "users", actions: [ "read", "create", "update", "delete" ] },
  # AI - full CRUD
  { resource: "ai", actions: [ "read", "create", "update", "delete" ] },
  # Speech - full CRUD
  { resource: "speech", actions: [ "read", "create", "update", "delete" ] }
]

user_permissions.each do |entry|
  entry[:actions].each do |action|
    perm = Iam::Permission.find_by(resource: entry[:resource], action: action)
    if perm
      Iam::RolePermission.create!(role: default_user, permission: perm)
    else
      puts "⚠️  Warning: Permission #{action}_#{entry[:resource]} not found"
    end
  end
end

puts "✅ #{Iam::RolePermission.count} role-permission assignments created"

# ===== DEFAULT ADMIN USERS =====
puts "🌱 Creating default admin users..."

super_admin_user = User.find_or_initialize_by(email: "super@admin.com")
super_admin_user.assign_attributes(
  username: "superadmin",
  name: "Super Admin User",
  password: "111111",
  password_confirmation: "111111",
  confirmed_at: Time.current
)
super_admin_user.save!

Iam::UserRole.find_or_create_by!(
  user: super_admin_user,
  role: super_admin
)

puts "✅ Super Admin user ready: super@admin.com / 111111"

admin_user = User.find_or_initialize_by(email: "just@admin.com")
admin_user.assign_attributes(
  username: "justadmin",
  name: "Just Admin User",
  password: "123456",
  password_confirmation: "123456",
  confirmed_at: Time.current
)
admin_user.save!

Iam::UserRole.find_or_create_by!(
  user: admin_user,
  role: admin
)

puts "✅ Admin user ready: just@admin.com / 123456"

# ===== AUTO-ASSIGN USER ROLE TO ALL EXISTING USERS =====
puts "🌱 Assigning default user role to all users without roles..."

User.all.each do |user|
  if user.user_roles.empty?
    Iam::UserRole.create!(user: user, role: default_user)
  end
end

puts "✅ #{User.count} users have roles assigned"

puts "✅ Seeding complete!"

puts "\n📋 Summary:"
puts "  - #{Iam::Permission.count} permissions"
puts "  - #{Iam::Role.count} roles"
puts "  - #{Iam::RolePermission.count} role-permission assignments"
puts "  - #{Iam::UserRole.count} user-role assignments"
puts "  - #{User.count} users"
