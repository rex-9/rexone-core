require "administrate/base_dashboard"

class AssetDashboard < Administrate::BaseDashboard
  # Display Resource
  def display_resource(asset)
    "#{asset.type} (#{asset.name})"
  end

  ATTRIBUTE_TYPES = {
    id: Field::String,
    type: Field::String,
    format: Field::String,
    extension: Field::String,
    size_bytes: Field::Number,
    duration_secs: Field::Number,
    source: Field::String,
    name: Field::String,
    url: Field::String,
    storage_key: Field::String,
    resource_model: Field::String,
    resource_id: Field::String,
    resource: Field::Polymorphic,
    created_by_id: Field::String,
    creator: Field::BelongsTo,
    updated_by_id: Field::String,
    updater: Field::BelongsTo,
    discarded_at: Field::DateTime,
    discarded_by_id: Field::String,
    discarder: Field::BelongsTo,
    undiscarded_at: Field::DateTime,
    undiscarded_by_id: Field::String,
    undiscarder: Field::BelongsTo,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    type
    format
    name
    resource_model
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    type
    format
    extension
    size_bytes
    duration_secs
    source
    name
    url
    storage_key
    resource_model
    resource_id
    creator
    updater
    discarded_at
    undiscarded_at
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    type
    format
    extension
    size_bytes
    duration_secs
    source
    name
    url
    storage_key
    resource_model
    resource_id
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
