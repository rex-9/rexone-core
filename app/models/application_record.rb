class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  include Discard::Model
  include Auditable

  default_scope -> { kept }
end
