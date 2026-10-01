# frozen_string_literal: true

# app/services/time_service.rb
# Universal UTC timestamp, epoch, and date serialization service.
# Enforces Constitutional Law U10 (Strict UTC Transport) & Law U14 (Clean Parameter Contracts).
class TimeService
  class << self
    # Current time in UTC (ActiveSupport::TimeWithZone)
    def current
      Time.current
    end

    # Converts ISO 8601 string, numeric epoch (seconds), or Time/Date object
    # into an Integer Unix timestamp (seconds since Unix epoch).
    # Returns nil if input is blank or unparseable.
    def to_epoch(value)
      return nil if value.blank?

      case value
      when Numeric
        value.to_i
      when Time, DateTime, ActiveSupport::TimeWithZone
        value.to_i
      when Date
        value.to_time.utc.to_i
      when String
        clean_value = value.strip
        return clean_value.to_i if clean_value.match?(/\A-?\d+\z/)

        Time.zone.parse(clean_value)&.to_i
      else
        nil
      end
    rescue ArgumentError, TypeError
      nil
    end

    # Parses any valid time representation (ISO 8601 string, numeric epoch, Date/Time)
    # into a UTC ActiveSupport::TimeWithZone instance.
    # Returns fallback if input is blank or invalid.
    def parse_utc(value, fallback: nil)
      return fallback if value.blank?

      time = case value
      when Numeric
        Time.at(value).in_time_zone("UTC")
      when Time, DateTime, ActiveSupport::TimeWithZone
        value.in_time_zone("UTC")
      when Date
        value.in_time_zone("UTC")
      when String
        clean_value = value.strip
        if clean_value.match?(/\A-?\d+\z/)
          Time.at(clean_value.to_i).in_time_zone("UTC")
        else
          Time.zone.parse(clean_value)&.in_time_zone("UTC")
        end
      else
        nil
      end

      time || fallback
    rescue ArgumentError, TypeError
      fallback
    end

    # Formats any date/time/epoch representation into a standard UTC ISO 8601 string.
    # Returns nil if input is blank or unparseable.
    def iso8601(value)
      return nil if value.blank?

      parse_utc(value)&.iso8601
    end
  end
end
