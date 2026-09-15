require "administrate/base_dashboard"

class UserNotificationDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::String,
    clients: Field::String,
    created_by_id: Field::String,
    creator: Field::BelongsTo,
    metadata: Field::String.with_options(searchable: false),
    discarded_at: Field::DateTime,
    discarded_by_id: Field::String,
    discarder: Field::BelongsTo,
    link: Field::String,
    message: Field::Text,
    notification: Field::BelongsTo,
    operation_id: Field::String,
    operation_status: Field::String,
    operation_type: Field::String,
    read_at: Field::DateTime,
    title: Field::String,
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
    link
    message
    clients
    metadata
    creator
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    clients
    created_by_id
    creator
    metadata
    discarded_at
    discarded_by_id
    discarder
    link
    message
    notification
    operation_id
    operation_status
    operation_type
    read_at
    title
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
    clients
    created_by_id
    creator
    metadata
    discarded_at
    discarded_by_id
    discarder
    link
    message
    notification
    operation_id
    operation_status
    operation_type
    read_at
    title
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

  # Overwrite this method to customize how user notifications are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(user_notification)
  #   "UserNotification ##{user_notification.id}"
  # end
end
