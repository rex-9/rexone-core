#!/bin/bash

# Comprehensive, idempotent database synchronization & backfill script.
# Safely updates schema and backfills data WITHOUT dropping tables or losing user data.

docker compose -f docker-compose.dev.yaml exec api bundle exec rails runner "
  ActiveRecord::Base.transaction do
    puts '========================================================'
    puts '🚀 STARTING DATABASE SYNCHRONIZATION & BACKFILL'
    puts '========================================================'

    # ----------------------------------------------------
    # 1. PAYMENT PRODUCTS: Code Column & Unique Backfill
    # ----------------------------------------------------
    puts '\n📦 [1/4] Synchronizing Payment Products...'
    unless ActiveRecord::Base.connection.column_exists?(:payment_products, :code)
      puts '  -> Adding missing \"code\" column to payment_products table...'
      ActiveRecord::Base.connection.add_column :payment_products, :code, :string
    end

    Payment::Product.with_discarded.find_each do |product|
      next if product.code.present?

      loop do
        gen_code = SecureRandom.alphanumeric(10)
        unless Payment::Product.exists?(code: gen_code)
          product.update_columns(code: gen_code)
          puts \"  -> Backfilled code '#{gen_code}' on product '#{product.name}' (ID: #{product.id})\"
          break
        end
      end
    end

    ActiveRecord::Base.connection.change_column_null :payment_products, :code, false

    unless ActiveRecord::Base.connection.index_exists?(:payment_products, :code)
      puts '  -> Adding unique index on payment_products(code)...'
      ActiveRecord::Base.connection.add_index :payment_products, :code, unique: true
    end
    puts '  ✅ Payment products fully synchronized.'

    # ----------------------------------------------------
    # 2. IAM: Permissions & System Roles Synchronization
    # ----------------------------------------------------
    puts '\n🔐 [2/4] Synchronizing IAM Permissions & Roles...'
    perm_count = 0
    Iam::Permission::RESOURCES.each do |resource|
      Iam::Permission::ACTIONS.each do |action|
        perm = Iam::Permission.find_or_create_by!(action: action, resource: resource) do |p|
          p.name = \"#{action}_#{resource}\"
        end
        perm_count += 1 if perm.previously_new_record?
      end
    end
    puts \"  -> Created #{perm_count} missing permissions (Total: #{Iam::Permission.count})\"

    super_admin_role = Iam::Role.find_or_create_by!(name: IamConstants::Role::SUPER_ADMIN) do |r|
      r.description = SeedConstants::RoleDescriptions::SUPER_ADMIN
      r.system = true
    end

    admin_role = Iam::Role.find_or_create_by!(name: IamConstants::Role::ADMIN) do |r|
      r.description = SeedConstants::RoleDescriptions::ADMIN
      r.system = true
    end

    default_user_role = Iam::Role.find_or_create_by!(name: IamConstants::Role::USER) do |r|
      r.description = SeedConstants::RoleDescriptions::USER
      r.system = true
    end

    # Super Admin: Ensure all permissions
    Iam::Permission.find_each do |perm|
      Iam::RolePermission.find_or_create_by!(role: super_admin_role, permission: perm)
    end

    # Admin: Ensure all non-restricted permissions
    Iam::Permission.where.not(resource: IamConstants::Role::RESTRICTED_FOR_ADMIN).find_each do |perm|
      Iam::RolePermission.find_or_create_by!(role: admin_role, permission: perm)
    end

    # Default User: Ensure user role permissions
    IamConstants::DefaultPermissions::USER.each do |entry|
      entry[:actions].each do |action|
        perm = Iam::Permission.find_by(resource: entry[:resource], action: action)
        if perm
          Iam::RolePermission.find_or_create_by!(role: default_user_role, permission: perm)
        end
      end
    end
    puts '  ✅ IAM roles and permissions synchronized.'

    # ----------------------------------------------------
    # 3. USERS: Ensure Every User Has a Role
    # ----------------------------------------------------
    puts '\n👥 [3/4] Ensuring All Users Have Roles Assigned...'
    orphaned_user_count = 0
    User.find_each do |user|
      if user.user_roles.empty?
        Iam::UserRole.create!(user: user, role: default_user_role)
        orphaned_user_count += 1
      end
    end
    puts \"  -> Assigned default 'user' role to #{orphaned_user_count} users without roles.\"
    puts '  ✅ User roles synchronized.'

    # ----------------------------------------------------
    # 4. ENTITLEMENT ACCESSES & LOGS: Backfill Timestamps
    # ----------------------------------------------------
    puts '\n📋 [4/4] Sanitizing Accesses and System Telemetry...'
    Access.where(granted_at: nil).find_each do |access|
      access.update_columns(granted_at: access.created_at || Time.current)
    end

    Access.where(status: nil).find_each do |access|
      new_status = (access.expires_at.nil? || access.expires_at > Time.current) ? AccessConstants::AccessStatus::ACTIVE : AccessConstants::AccessStatus::EXPIRED
      access.update_columns(status: new_status)
    end

    if defined?(Log::Client)
      Log::Client.where(occurrence_count: nil).update_all(occurrence_count: 1)
    end
    puts '  ✅ Accesses and client logs sanitized.'

    puts '\n========================================================'
    puts '🎉 ALL DATABASE SYNCHRONIZATIONS & BACKFILLS COMPLETED!'
    puts '========================================================'
  end
"
