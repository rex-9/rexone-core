# app/models/iam/user_role.rb:

module Iam
  class UserRole < ApplicationRecord
    self.table_name = "iam_user_roles"

    belongs_to :user
    belongs_to :role, class_name: "Iam::Role"

    validates :user_id, uniqueness: { scope: :role_id }
  end
end
