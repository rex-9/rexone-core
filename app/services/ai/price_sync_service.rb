# frozen_string_literal: true

require "net/http"
require "json"
require "bigdecimal"
require "bigdecimal/util"

module Ai
  class PriceSyncService
    class << self
      def sync!
        payload = fetch_pricing_payload
        return if payload.blank?

        sync_from_payload(payload)
      rescue StandardError => e
        Rails.logger.warn("[Ai::PriceSyncService] Remote sync failed: #{e.message}")
        nil
      end

      private

      def fetch_pricing_payload
        uri = URI(AiConstants::Pricing::PRICING_REGISTRY_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = AiConstants::Pricing::SYNC_OPEN_TIMEOUT
        http.read_timeout = AiConstants::Pricing::SYNC_READ_TIMEOUT

        response = http.get(uri.request_uri)
        return nil unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      rescue StandardError
        nil
      end

      def sync_from_payload(data)
        tracked_providers = AiConstants::Provider::ALL

        data.each do |model_key, info|
          next unless info.is_a?(Hash)

          raw_provider = (info[AiConstants::Pricing::RegistryKeys::PROVIDER] || "").downcase
          next unless tracked_providers.include?(raw_provider)

          provider = raw_provider
          divisor = AiConstants::Pricing::PER_MILLION.to_d
          precision = AiConstants::Pricing::DECIMAL_PRECISION

          input_cost = (info[AiConstants::Pricing::RegistryKeys::INPUT_COST].to_d * divisor).round(precision)
          cached_cost =
            if info[AiConstants::Pricing::RegistryKeys::CACHED_INPUT_COST]
              (info[AiConstants::Pricing::RegistryKeys::CACHED_INPUT_COST].to_d * divisor).round(precision)
            else
              (input_cost * AiConstants::Pricing::DEFAULT_CACHE_DISCOUNT_RATIO.to_d).round(precision)
            end
          output_cost = (info[AiConstants::Pricing::RegistryKeys::OUTPUT_COST].to_d * divisor).round(precision)

          next if input_cost.zero? && output_cost.zero?

          clean_model = model_key.sub(%r{^[^/]+/}, "")

          price = Ai::Price.find_or_initialize_by(provider: provider, model: clean_model)
          price.input_cost_per_million = input_cost
          price.cached_cost_per_million = cached_cost
          price.output_cost_per_million = output_cost
          price.currency = AiConstants::Pricing::DEFAULT_CURRENCY
          price.discarded_at = nil
          price.save!
        end
      end
    end
  end
end
