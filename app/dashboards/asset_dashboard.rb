require "administrate/base_dashboard"

class AssetDashboard < Administrate::BaseDashboard
  # Display Resource
  def display_resource(asset)
    "#{asset.type} (#{asset.name})"
  end

  ATTRIBUTE_TYPES = {
    id: Field::String,
    title: Field::String,
    name: Field::String,
    description: Field::Text,
    type: Field::String,
    format: Field::String,
    status: Field::String,
    extension: Field::String,
    size_bytes: Field::Number,
    duration_secs: Field::Number,
    source: Field::String,
    url: Field::String,
    storage_key: Field::String,
    metadata: Field::String.with_options(searchable: false),
    parent_asset: Field::BelongsTo,
    parent_asset_id: Field::String,
    thumbnail: Field::HasOne,
    subtitles: Field::HasMany,
    assetable_type: Field::String,
    assetable_id: Field::String,
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
    name
    title
    type
    format
    status
    assetable_type
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    title
    name
    description
    type
    format
    status
    extension
    size_bytes
    duration_secs
    source
    url
    storage_key
    metadata
    parent_asset
    thumbnail
    subtitles
    assetable_type
    assetable_id
    creator
    updater
    discarder
    undiscarder
    discarded_at
    undiscarded_at
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    title
    name
    description
    type
    format
    status
    extension
    size_bytes
    duration_secs
    source
    url
    storage_key
    metadata
    parent_asset_id
    assetable_type
    assetable_id
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
