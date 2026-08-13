require "administrate/base_dashboard"

class Log::ClientDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::String,
    app_version: Field::String,
    browser: Field::String,
    context: Field::String.with_options(searchable: false),
    cookies: Field::String.with_options(searchable: false),
    created_by_id: Field::String,
    creator: Field::BelongsTo,
    discarded_at: Field::DateTime,
    discarder: Field::BelongsTo,
    environment: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    last_occurred_at: Field::DateTime,
    local_storage_keys: Field::String.with_options(searchable: false),
    message: Field::String,
    method: Field::String,
    occurrence_count: Field::Number,
    platform: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    request_id: Field::String,
    resolved_at: Field::DateTime,
    resolved_by: Field::BelongsTo,
    session_storage_keys: Field::String.with_options(searchable: false),
    severity: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    stack_trace: Field::String.with_options(searchable: false),
    undiscarder: Field::BelongsTo,
    updated_by_id: Field::String,
    updater: Field::BelongsTo,
    url: Field::String,
    user: Field::BelongsTo,
    user_agent: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    severity
    message
    platform
    app_version
    browser
    context
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    app_version
    browser
    context
    cookies
    created_by_id
    creator
    discarded_at
    discarder
    environment
    last_occurred_at
    local_storage_keys
    message
    method
    occurrence_count
    platform
    request_id
    resolved_at
    resolved_by
    session_storage_keys
    severity
    stack_trace
    undiscarder
    updated_by_id
    updater
    url
    user
    user_agent
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    app_version
    browser
    context
    cookies
    created_by_id
    creator
    discarded_at
    discarder
    environment
    last_occurred_at
    local_storage_keys
    message
    method
    occurrence_count
    platform
    request_id
    resolved_at
    resolved_by
    session_storage_keys
    severity
    stack_trace
    undiscarder
    updated_by_id
    updater
    url
    user
    user_agent
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how clients are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(client)
  #   "Log::Client ##{client.id}"
  # end
end
