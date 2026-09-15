# frozen_string_literal: true

# app/constants/seed_constants.rb
module SeedConstants
  module RoleDescriptions
    SUPER_ADMIN = "Full system access".freeze
    ADMIN       = "Admin with limited role management".freeze
    USER        = "Default user role for all registered users".freeze
  end
end
