require "administrate/base_dashboard"

class Client::VersionDashboard < Administrate::BaseDashboard
  def display_resource(version)
    "#{version.number} — #{version.title}"
  end

  ATTRIBUTE_TYPES = {
    id: Field::String,
    number: Field::String,
    title: Field::String,
    description: Field::Text,
    status: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    is_force_update: Field::Boolean,
    released_at: Field::DateTime,
    ios_build_number: Field::Number,
    android_build_number: Field::Number,
    metadata: Field::String.with_options(searchable: false),
    user_versions: Field::HasMany,
    created_by_id: Field::String,
    creator: Field::BelongsTo,
    discarded_at: Field::DateTime,
    discarded_by_id: Field::String,
    discarder: Field::BelongsTo,
    undiscarded_at: Field::DateTime,
    undiscarded_by_id: Field::String,
    undiscarder: Field::BelongsTo,
    updated_by_id: Field::String,
    updater: Field::BelongsTo,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    number
    title
    status
    is_force_update
    released_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    number
    title
    description
    status
    is_force_update
    released_at
    ios_build_number
    android_build_number
    metadata
    user_versions
    creator
    updater
    discarder
    discarded_at
    undiscarder
    undiscarded_at
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    number
    title
    description
    is_force_update
    status
    ios_build_number
    android_build_number
    metadata
  ].freeze

  COLLECTION_FILTERS = {}.freeze
end
