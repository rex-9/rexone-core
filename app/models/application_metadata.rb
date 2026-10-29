# frozen_string_literal: true

# app/models/application_metadata.rb
# Constitutional base class for all typed JSONB metadata and payload contracts.
# Guarantees deterministic attributes, type casting, validation, and serialization.
# Eliminates raw hash manipulation, fallback guessing, and loose key diging (Law U14 & U15).
class ApplicationMetadata
  include ActiveModel::Model
  include ActiveModel::Attributes

  class Type < ActiveRecord::Type::Json
    def initialize(target_class)
      @target_class = target_class
      super()
    end

    def cast(value)
      if value.is_a?(@target_class)
        value
      elsif value.is_a?(Hash) || value.respond_to?(:to_unsafe_h) || value.respond_to?(:to_h)
        @target_class.from_h(value)
      elsif value.is_a?(String)
        begin
          parsed = JSON.parse(value)
          parsed.is_a?(Hash) ? @target_class.from_h(parsed) : @target_class.new
        rescue JSON::ParserError
          @target_class.new
        end
      else
        @target_class.new
      end
    end

    def serialize(value)
      super(value.respond_to?(:to_h) ? value.to_h : value)
    end

    def deserialize(value)
      cast(super(value))
    end

    def changed_in_place?(raw_old_value, new_value)
      serialize(new_value) != raw_old_value
    end
  end

  class JobSerializer < ActiveJob::Serializers::ObjectSerializer
    def serialize?(argument)
      argument.is_a?(ApplicationMetadata)
    end

    def klass
      ApplicationMetadata
    end

    def serialize(metadata)
      super(
        "class" => metadata.class.name,
        "data" => metadata.to_h
      )
    end

    def deserialize(hash)
      hash["class"].constantize.from_h(hash["data"])
    end
  end

  def self.to_type
    Type.new(self)
  end

  attr_accessor :unrecognized_keys

  validate :validate_no_unrecognized_keys

  def to_h
    attributes.compact
  end
  alias_method :to_hash, :to_h

  def to_json(*args)
    to_h.to_json(*args)
  end

  def as_json(options = nil)
    to_h.as_json(options)
  end

  def [](key)
    public_send(key) if respond_to?(key)
  end

  def []=(key, value)
    setter = "#{key}="
    if respond_to?(setter)
      public_send(setter, value)
    else
      self.unrecognized_keys ||= []
      self.unrecognized_keys << key.to_s
    end
  end

  def key?(key)
    self.class.attribute_names.include?(key.to_s)
  end
  alias_method :has_key?, :key?

  def dig(*keys)
    to_h.dig(*keys.map(&:to_s))
  end

  def ==(other)
    if other.is_a?(ApplicationMetadata)
      to_h == other.to_h
    elsif other.is_a?(Hash)
      to_h == other.deep_stringify_keys
    else
      super
    end
  end
  alias_method :eql?, :==

  def empty?
    attributes.compact.empty? && unrecognized_keys.blank?
  end

  def blank?
    empty?
  end

  def present?
    !empty?
  end

  delegate :merge, :keys, :values, :slice, :except, :symbolize_keys, :deep_symbolize_keys, :stringify_keys, :deep_stringify_keys,
           :each, :each_pair, :each_key, :each_value, :transform_values, :transform_keys, to: :to_h

  def self.from_h(raw)
    hash =
      if raw.respond_to?(:to_unsafe_h)
        raw.to_unsafe_h
      elsif raw.respond_to?(:to_h)
        raw.to_h
      else
        {}
      end
    data = hash.is_a?(Hash) ? hash.deep_stringify_keys : {}
    known = attribute_names.to_set
    unknown = data.keys.reject { |k| known.include?(k) }
    instance = new(data.slice(*known))
    instance.unrecognized_keys = unknown
    instance
  end

  private

  def validate_no_unrecognized_keys
    return if unrecognized_keys.blank?

    unrecognized_keys.each do |key|
      errors.add(:base, "unrecognized metadata key '#{key}'")
    end
  end
end

ActiveSupport.on_load(:active_job) do
  ActiveJob::Serializers.add_serializers ApplicationMetadata::JobSerializer
end
