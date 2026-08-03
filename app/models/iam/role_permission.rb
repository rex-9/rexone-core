# app/models/iam/role_permission.rb:

module Iam
  class RolePermission < ApplicationRecord
    self.table_name = "iam_role_permissions"

    belongs_to :role, class_name: "Iam::Role"
    belongs_to :permission, class_name: "Iam::Permission"

    validates :role_id, uniqueness: { scope: :permission_id }
  end
end
