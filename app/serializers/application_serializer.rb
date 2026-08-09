# app/serializers/application_serializer.rb

class ApplicationSerializer
  include JSONAPI::Serializer

  # Set default attributes
  attributes :id

  # Set meta for pagination
  class << self
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
