require "administrate/base_dashboard"

class AssetDashboard < Administrate::BaseDashboard
  # Display Resource
  def display_resource(asset)
    "#{asset.category} (#{asset.user})"
  end

  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::String,
    category: Field::String,
    created_by_id: Field::String,
    creator: Field::BelongsTo,
    discarded_at: Field::DateTime,
    discarded_by_id: Field::String,
    discarder: Field::BelongsTo,
    extension: Field::String,
    format: Field::String,
    name: Field::String,
    public_id: Field::String,
    record: Field::Polymorphic,
    size: Field::Number,
    source: Field::String,
    undiscarded_at: Field::DateTime,
    undiscarded_by_id: Field::String,
    undiscarder: Field::BelongsTo,
    updated_by_id: Field::String,
    updater: Field::BelongsTo,
    url: Field::String,
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
    id
    category
    extension
    format
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    category
    created_by_id
    creator
    discarded_at
    discarded_by_id
    discarder
    extension
    format
    name
    public_id
    record
    size
    source
    undiscarded_at
    undiscarded_by_id
    undiscarder
    updated_by_id
    updater
    url
    user
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    category
    created_by_id
    creator
    discarded_at
    discarded_by_id
    discarder
    extension
    format
    name
    public_id
    record
    size
    source
    undiscarded_at
    undiscarded_by_id
    undiscarder
    updated_by_id
    updater
    url
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

  # Overwrite this method to customize how assets are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(asset)
  #   "Asset ##{asset.id}"
  # end
end
