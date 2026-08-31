# app/models/iam/role.rb:

module Iam
  class Role < ApplicationRecord
    self.table_name = "iam_roles"

    has_many :user_roles, dependent: :destroy
    has_many :users, through: :user_roles
    has_many :role_permissions, dependent: :destroy
    has_many :permissions, through: :role_permissions

    validates :name, presence: true, uniqueness: true

    scope :system, -> { where(system: true) }
    scope :admin_roles, -> { where("name ILIKE '%admin%'") }
    scope :non_admin_roles, -> { where.not("name ILIKE '%admin%'") }

    def admin?
      name.to_s.downcase.include?("admin")
    end

    def has_permission?(action, resource)
      permissions.exists?(action: action.to_s, resource: resource.to_s)
    end

    def can?(action, resource)
      has_permission?(action, resource)
    end

    def grant_permission(permission)
      role_permissions.find_or_create_by!(permission: permission)
    end

    def revoke_permission(permission)
      role_permissions.find_by(permission: permission)&.destroy
    end
  end
end
