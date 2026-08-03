# app/models/iam/permission.rb

module Iam
  class Permission < ApplicationRecord
    self.table_name = "iam_permissions"

    enum :action, {
      read: "read",
      create: "create",
      update: "update",
      delete: "delete"
    }, prefix: true, validate: true

    # These are CONTROLLER names, not model names
    enum :resource, {
      # Main controllers
      users: "users",
      roles: "roles",
      permissions: "permissions",
      products: "products",
      payments: "payments",
      subscriptions: "subscriptions",
      transactions: "transactions",
      accesses: "accesses",
      chat: "chat",
      assets: "assets",
      dashboard: "dashboard",
      ai: "ai"
    }, prefix: true, validate: true

    has_many :role_permissions, dependent: :destroy
    has_many :roles, through: :role_permissions

    validates :name, presence: true, uniqueness: true
    validates :action, presence: true, inclusion: { in: actions.keys }
    validates :resource, presence: true, inclusion: { in: resources.keys }

    scope :for_resource, ->(resource) { where(resource: resource) }
    scope :for_action, ->(action) { where(action: action) }

    before_validation :set_name, on: :create

    private

    def set_name
      self.name = "#{action}_#{resource}" if action.present? && resource.present?
    end
  end
end
