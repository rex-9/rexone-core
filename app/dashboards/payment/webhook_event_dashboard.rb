require "administrate/base_dashboard"

class Payment::WebhookEventDashboard < Administrate::BaseDashboard
  # Display Resource
  def display_resource(event)
    event.event_type
  end

  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::String,
    attempt_count: Field::Number,
    created_by_id: Field::String,
    creator: Field::BelongsTo,
    discarded_at: Field::DateTime,
    discarded_by_id: Field::String,
    discarder: Field::BelongsTo,
    event_type: Field::String,
    last_error: Field::Text,
    livemode: Field::Boolean,
    payload: Field::String.with_options(searchable: false),
    processed_at: Field::DateTime,
    processing_started_at: Field::DateTime,
    received_at: Field::DateTime,
    status: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    stripe_event_id: Field::String,
    undiscarded_at: Field::DateTime,
    undiscarded_by_id: Field::String,
    undiscarder: Field::BelongsTo,
    updated_by_id: Field::String,
    updater: Field::BelongsTo,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    event_type
    attempt_count
    status
    last_error
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    attempt_count
    created_by_id
    creator
    discarded_at
    discarded_by_id
    discarder
    event_type
    last_error
    livemode
    payload
    processed_at
    processing_started_at
    received_at
    status
    stripe_event_id
    undiscarded_at
    undiscarded_by_id
    undiscarder
    updated_by_id
    updater
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    attempt_count
    created_by_id
    creator
    discarded_at
    discarded_by_id
    discarder
    event_type
    last_error
    livemode
    payload
    processed_at
    processing_started_at
    received_at
    status
    stripe_event_id
    undiscarded_at
    undiscarded_by_id
    undiscarder
    updated_by_id
    updater
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

  # Overwrite this method to customize how webhook events are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(webhook_event)
  #   "Payment::WebhookEvent ##{webhook_event.id}"
  # end
end
