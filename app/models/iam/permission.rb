# app/models/iam/permission.rb
module Iam
  class Permission < ApplicationRecord
    self.table_name = "iam_permissions"

    # ===== CONSTANTS =====
    # These are CONTROLLER names, not model names
    # Add new controllers here when they are created
    RESOURCES = %w[
      users
      roles
      user_roles
      permissions
      products
      payments
      subscriptions
      transactions
      access
      assets
      notifications
      ai
      speech
      clients
    ].freeze

    ACTIONS = %w[read create update delete].freeze
    RESOURCES = IamConstants::Resource::ALL
    ACTIONS = IamConstants::Action::ALL

    # ===== ENUMS =====
    enum :action, {
      read: "read",
      create: "create",
      update: "update",
      delete: "delete"
    }, prefix: true, validate: true

    enum :resource, RESOURCES.index_with(&:itself), prefix: true, validate: true

    # ===== ASSOCIATIONS =====
    has_many :role_permissions, dependent: :destroy
    has_many :roles, through: :role_permissions

    # ===== VALIDATIONS =====
    validates :name, presence: true, uniqueness: true
    validates :action, presence: true, inclusion: { in: ACTIONS }
    validates :resource, presence: true, inclusion: { in: RESOURCES }

    # ===== SCOPES =====
    scope :for_resource, ->(resource) { where(resource: resource) }
    scope :for_action, ->(action) { where(action: action) }

    # ===== CALLBACKS =====
    before_validation :set_name, on: :create

    private

    def set_name
      self.name = "#{action}_#{resource}" if action.present? && resource.present?
    end
  end
end
