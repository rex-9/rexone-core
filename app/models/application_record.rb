class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  include Discard::Model
  include Auditable

  default_scope -> { kept }

  class << self
    def has_metadata(metadata_class, attribute_name: :metadata)
      attribute attribute_name, metadata_class.to_type, default: -> { metadata_class.new }

      validate do
        meta = public_send(attribute_name)
        if meta && !meta.valid?
          meta.errors.each do |error|
            if error.attribute == :base
              errors.add(attribute_name, error.message)
            else
              errors.add("#{attribute_name}.#{error.attribute}", error.message)
            end
          end
        end
      end
    end
  end
end
