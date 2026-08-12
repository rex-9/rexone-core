require "administrate/base_dashboard"

class Payment::SubscriptionDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::String,
    canceled_at: Field::DateTime,
    created_by_id: Field::String,
    creator: Field::BelongsTo,
    current_period_end: Field::DateTime,
    current_period_start: Field::DateTime,
    cycle: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    discarded_at: Field::DateTime,
    discarded_by_id: Field::String,
    discarder: Field::BelongsTo,
    ended_at: Field::DateTime,
    metadata: Field::String.with_options(searchable: false),
    payment_method_details: Field::String.with_options(searchable: false),
    payment_method_id: Field::String,
    payment_method_type: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    product: Field::BelongsTo,
    started_at: Field::DateTime,
    status: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    stripe_customer_id: Field::String,
    stripe_subscription_id: Field::String,
    undiscarded_at: Field::DateTime,
    undiscarded_by_id: Field::String,
    undiscarder: Field::BelongsTo,
    updated_by_id: Field::String,
    updater: Field::BelongsTo,
    user: Field::BelongsTo,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    current_period_start
    current_period_end
    cycle
    product
    user
    status
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    canceled_at
    created_by_id
    creator
    current_period_end
    current_period_start
    cycle
    discarded_at
    discarded_by_id
    discarder
    ended_at
    metadata
    payment_method_details
    payment_method_id
    payment_method_type
    product
    started_at
    status
    stripe_customer_id
    stripe_subscription_id
    undiscarded_at
    undiscarded_by_id
    undiscarder
    updated_by_id
    updater
    user
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    canceled_at
    created_by_id
    creator
    current_period_end
    current_period_start
    cycle
    discarded_at
    discarded_by_id
    discarder
    ended_at
    metadata
    payment_method_details
    payment_method_id
    payment_method_type
    product
    started_at
    status
    stripe_customer_id
    stripe_subscription_id
    undiscarded_at
    undiscarded_by_id
    undiscarder
    updated_by_id
    updater
    user
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

  # Overwrite this method to customize how subscriptions are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(subscription)
  #   "Payment::Subscription ##{subscription.id}"
  # end
end
