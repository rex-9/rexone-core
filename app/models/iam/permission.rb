# app/models/iam/permission.rb

module Iam
  class Permission < ApplicationRecord
    self.table_name = "iam_permissions"

    has_many :role_permissions, dependent: :destroy
    has_many :roles, through: :role_permissions

    validates :name, presence: true, uniqueness: true
    validates :action, presence: true, inclusion: { in: %w[read create update delete] }
    validates :resource, presence: true

    scope :for_resource, ->(resource) { where(resource: resource) }
  end
end
