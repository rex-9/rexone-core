# db/seeds.rb

# ===== IAM PERMISSIONS =====
puts "🌱 Seeding IAM permissions..."

puts "🗑️  Clearing existing IAM data..."
Iam::RolePermission.delete_all
Iam::UserRole.delete_all
Iam::Role.delete_all
Iam::Permission.delete_all

puts "✅ IAM data cleared"

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
  name: IamConstants::Role::SUPER_ADMIN,
  description: SeedConstants::RoleDescriptions::SUPER_ADMIN,
  system: true
)

admin = Iam::Role.create!(
  name: IamConstants::Role::ADMIN,
  description: SeedConstants::RoleDescriptions::ADMIN,
  system: true
)

default_user = Iam::Role.create!(
  name: IamConstants::Role::USER,
  description: SeedConstants::RoleDescriptions::USER,
  system: true
)

puts "✅ #{Iam::Role.count} roles created"

# ===== ASSIGN PERMISSIONS TO ROLES =====
puts "🌱 Assigning permissions to roles..."

# Super Admin: ALL permissions
Iam::Permission.find_each do |perm|
  Iam::RolePermission.create!(role: super_admin, permission: perm)
end

# Admin: ALL permissions EXCEPT User, IAM, version, and user version management
Iam::Permission.where.not(resource: IamConstants::Role::RESTRICTED_FOR_ADMIN).find_each do |perm|
  Iam::RolePermission.create!(role: admin, permission: perm)
end

# Default User Role Permissions
puts "🌱 Assigning permissions to default user role..."

IamConstants::DefaultPermissions::USER.each do |entry|
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

# ===== AUTO-ASSIGN USER ROLE TO ALL EXISTING USERS =====
puts "🌱 Assigning default user role to all users without roles..."

User.find_each do |user|
  if user.user_roles.empty?
    Iam::UserRole.create!(user: user, role: default_user)
  end
end

puts "✅ #{User.count} users have roles assigned"

# ===== DEFAULT NOTIFICATIONS =====
puts "🌱 Seeding default notifications..."

NotificationConstants::DefaultNotifications::ALL.each do |noti_data|
  noti = Notification.find_or_initialize_by(event: noti_data[:event])
  noti.assign_attributes(noti_data)
  noti.save!
end

puts "✅ #{Notification.count} notifications ready"

puts "🌱 Seeding AI profiles..."
Ai::ProfileService.create_defaults!
puts "✅ #{Ai::Profile.count} AI profiles ready"

puts "✅ Seeding complete!"

puts "\n📋 Summary:"
puts "  - #{Iam::Permission.count} permissions"
puts "  - #{Iam::Role.count} roles"
puts "  - #{Iam::RolePermission.count} role-permission assignments"
puts "  - #{Iam::UserRole.count} user-role assignments"
puts "  - #{User.count} users"
puts "  - #{Ai::Profile.count} AI profiles"
