require "administrate/base_dashboard"

class Payment::TransactionDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::String,
    amount_capturable: Field::Number,
    amount_received: Field::Number,
    canceled_at: Field::DateTime,
    client_secret: Field::String,
    currency: Field::String,
    metadata: Field::String.with_options(searchable: false),
    paid_at: Field::DateTime,
    payment_method_details: Field::String.with_options(searchable: false),
    payment_method_id: Field::String,
    payment_method_type: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    price_unit_amount: Field::Number,
    processing_at: Field::DateTime,
    product: Field::BelongsTo,
    refunded_at: Field::DateTime,
    status: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    stripe_charge_id: Field::String,
    stripe_customer_id: Field::String,
    stripe_payment_intent_id: Field::String,
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
    price_unit_amount
    currency
    amount_received
    amount_capturable
    product
    user
    paid_at
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    amount_capturable
    amount_received
    canceled_at
    client_secret
    currency
    metadata
    paid_at
    payment_method_details
    payment_method_id
    payment_method_type
    price_unit_amount
    processing_at
    product
    refunded_at
    status
    stripe_charge_id
    stripe_customer_id
    stripe_payment_intent_id
    user
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    amount_capturable
    amount_received
    canceled_at
    client_secret
    currency
    metadata
    paid_at
    payment_method_details
    payment_method_id
    payment_method_type
    price_unit_amount
    processing_at
    product
    refunded_at
    status
    stripe_charge_id
    stripe_customer_id
    stripe_payment_intent_id
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

  # Overwrite this method to customize how transactions are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(transaction)
  #   "Payment::Transaction ##{transaction.id}"
  # end
end
