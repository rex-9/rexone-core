# app/constants/seed_constants.rb

module SeedConstants
  module RoleDescriptions
    SUPER_ADMIN = "Full system access".freeze
    ADMIN       = "Admin with limited role management".freeze
    USER        = "Default user role for all registered users".freeze
  end

  module Accounts
    SUPER_ADMIN = {
      email: "super@admin.com",
      username: "superadmin",
      name: "Super Admin User",
      password: "111111",
      password_confirmation: "111111"
    }.freeze

    ADMIN = {
      email: "just@admin.com",
      username: "justadmin",
      name: "Just Admin User",
      password: "123456",
      password_confirmation: "123456"
    }.freeze
  end
end
