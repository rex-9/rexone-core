# app/serializers/application_serializer.rb

class ApplicationSerializer
  include JSONAPI::Serializer

  # Set default attributes
  attributes :id

  # Set meta for pagination
  class << self
    def record(record, options = {})
      return nil if record.nil?

      new(record, options).serializable_hash[:data]
    end
    alias_method :resource, :record

    def collection(collection, options = {})
      return [] if collection.blank?

      new(collection, options).serializable_hash[:data] || []
    end

    def record_attributes(record, options = {})
      return nil if record.nil?

      new(record, options).serializable_hash.dig(:data, :attributes)
    end

    def collection_attributes(collection, options = {})
      return [] if collection.blank?

      items = new(collection, options).serializable_hash[:data]
      return [] unless items.is_a?(Array)

      items.map { |item| item[:attributes] }
    end

    def paginated(collection, pagy, options = {})
      serialized = new(collection, options).serializable_hash

      serialized.merge(
        meta: {
          pagination: {
            current_page: pagy.page,
            total_pages: pagy.pages,
            total_count: pagy.count,
            limit: pagy.limit,
            next_page: pagy.next,
            prev_page: pagy.previous
            # Optional: Add pagy URL helpers
            # first_url: pagy_url_for(pagy, 1),
            # last_url: pagy_url_for(pagy, pagy.pages),
            # next_url: pagy_url_for(pagy, pagy.next),
            # prev_url: pagy_url_for(pagy, pagy.prev)
          }
        }
      )
    end
  end
end
