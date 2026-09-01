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

# Admin: ALL permissions EXCEPT User and IAM management
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

# ===== DEFAULT ADMIN USERS =====
puts "🌱 Creating default admin users..."

super_admin_account = SeedConstants::Accounts::SUPER_ADMIN
super_admin_user = User.find_or_initialize_by(email: super_admin_account[:email])
super_admin_user.assign_attributes(
  username: super_admin_account[:username],
  name: super_admin_account[:name],
  password: super_admin_account[:password],
  password_confirmation: super_admin_account[:password_confirmation],
  confirmed_at: Time.current
)
super_admin_user.save!

Iam::UserRole.find_or_create_by!(
  user: super_admin_user,
  role: super_admin
)

puts "✅ Super Admin user ready: #{super_admin_account[:email]} / #{super_admin_account[:password]}"

admin_account = SeedConstants::Accounts::ADMIN
admin_user = User.find_or_initialize_by(email: admin_account[:email])
admin_user.assign_attributes(
  username: admin_account[:username],
  name: admin_account[:name],
  password: admin_account[:password],
  password_confirmation: admin_account[:password_confirmation],
  confirmed_at: Time.current
)
admin_user.save!

Iam::UserRole.find_or_create_by!(
  user: admin_user,
  role: admin
)

puts "✅ Admin user ready: #{admin_account[:email]} / #{admin_account[:password]}"

# ===== AUTO-ASSIGN USER ROLE TO ALL EXISTING USERS =====
puts "🌱 Assigning default user role to all users without roles..."

User.find_each do |user|
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
