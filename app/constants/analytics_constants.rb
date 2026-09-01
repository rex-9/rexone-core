# frozen_string_literal: true

# app/constants/analytics_constants.rb
module AnalyticsConstants
  module Period
    TODAY       = "today".freeze
    YESTERDAY   = "yesterday".freeze
    SEVEN_DAYS  = "7d".freeze
    THIRTY_DAYS = "30d".freeze
    THIS_MONTH  = "this_month".freeze
    LAST_MONTH  = "last_month".freeze
    THIS_YEAR   = "this_year".freeze
    LAST_YEAR   = "last_year".freeze
    CUSTOM      = "custom".freeze
    ALL         = [
      TODAY, YESTERDAY, SEVEN_DAYS, THIRTY_DAYS,
      THIS_MONTH, LAST_MONTH, THIS_YEAR, LAST_YEAR, CUSTOM
    ].freeze
  end

  module Grain
    HOURLY  = "hourly".freeze
    DAILY   = "daily".freeze
    MONTHLY = "monthly".freeze
    ALL     = [ HOURLY, DAILY, MONTHLY ].freeze
  end
end
