# frozen_string_literal: true

# app/services/ai/profile_service.rb
module Ai
  class ProfileService
    Error = Class.new(StandardError)

    DEFAULTS = AiConstants::Defaults::PROFILES

    PRICE_KEYS = %i[
      input_cost_per_million
      cached_cost_per_million
      output_cost_per_million
    ].freeze

    class << self
      def list(params = {})
        ensure_defaults!
        scope = Ai::Profile.all
        if AiConstants::Filter::STATUS_ENABLED.key?(params[:status])
          scope = scope.where(enabled: AiConstants::Filter::STATUS_ENABLED[params[:status]])
        elsif params[:enabled].present? && params[:enabled] != AiConstants::Filter::ALL
          scope = scope.where(enabled: ActiveModel::Type::Boolean.new.cast(params[:enabled]))
        end
        scope = scope.where(provider: params[:provider]) if params[:provider].present? && params[:provider] != AiConstants::Filter::ALL
        scope = scope.where(model: params[:model]) if params[:model].present? && params[:model] != AiConstants::Filter::ALL
        if params[:search].present?
          scope = scope.where(
            "name ILIKE :q OR key ILIKE :q OR provider ILIKE :q OR model ILIKE :q",
            q: "%#{params[:search]}%"
          )
        end
        scope
      end

      def find(id_or_key)
        if id_or_key.to_s.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
          Ai::Profile.find(id_or_key)
        else
          Ai::Profile.find_by!(key: id_or_key)
        end
      end

      def create!(attributes)
        attrs = attributes.to_h.symbolize_keys
        pricing_attrs = attrs.extract!(*PRICE_KEYS)
        default_profile = Ai::Profile.find_by(key: AiConstants::ProfileKey::CHAT)
        resolved_provider = (attrs[:provider].presence || default_profile&.provider || AiConstants::Provider::DEFAULT).to_s.downcase
        attrs[:provider] = resolved_provider
        attrs[:model] = (attrs[:model].presence || default_model_for_provider(resolved_provider, default_profile)).to_s.strip
        attrs[:temperature] = attrs[:temperature].presence || AiConstants::Defaults::TEMPERATURE
        attrs[:max_output_tokens] = attrs[:max_output_tokens].presence || AiConstants::Defaults::MAX_OUTPUT_TOKENS
        attrs[:context_max_tokens] = attrs[:context_max_tokens].presence || AiConstants::Defaults::CONTEXT_MAX_TOKENS
        attrs[:history_max_messages] = attrs[:history_max_messages].presence || AiConstants::Defaults::HISTORY_MAX_MESSAGES
        attrs[:timeout_seconds] = attrs[:timeout_seconds].presence || AiConstants::Defaults::TIMEOUT_SECONDS
        attrs[:enabled] = true if attrs[:enabled].nil?

        normalized_key = attrs[:key].to_s.strip
        existing_profile = Ai::Profile.with_discarded.find_by(key: normalized_key) if normalized_key.present?
        if existing_profile && (existing_profile.discarded? || AiConstants::ProfileKey::ALL.include?(normalized_key))
          existing_profile.assign_attributes(attrs.merge(discarded_at: nil))
          existing_profile.save!
          profile = existing_profile
        else
          profile = Ai::Profile.create!(attrs)
        end

        upsert_model_price!(profile.provider, profile.model, pricing_attrs)
        profile
      end

      def update!(profile, attributes)
        attrs = attributes.to_h.symbolize_keys
        pricing_attrs = attrs.extract!(*PRICE_KEYS)
        attrs[:provider] = attrs[:provider].to_s.downcase if attrs[:provider].present?
        attrs[:model] = attrs[:model].to_s.strip if attrs[:model].present?
        attrs[:temperature] = profile.temperature || AiConstants::Defaults::TEMPERATURE if attrs.key?(:temperature) && attrs[:temperature].blank?
        attrs[:max_output_tokens] = profile.max_output_tokens || AiConstants::Defaults::MAX_OUTPUT_TOKENS if attrs.key?(:max_output_tokens) && attrs[:max_output_tokens].blank?
        attrs[:context_max_tokens] = profile.context_max_tokens || AiConstants::Defaults::CONTEXT_MAX_TOKENS if attrs.key?(:context_max_tokens) && attrs[:context_max_tokens].blank?
        attrs[:history_max_messages] = profile.history_max_messages || AiConstants::Defaults::HISTORY_MAX_MESSAGES if attrs.key?(:history_max_messages) && attrs[:history_max_messages].blank?
        attrs[:timeout_seconds] = profile.timeout_seconds || AiConstants::Defaults::TIMEOUT_SECONDS if attrs.key?(:timeout_seconds) && attrs[:timeout_seconds].blank?
        profile.update!(attrs)
        upsert_model_price!(profile.provider, profile.model, pricing_attrs)
        profile
      end

      def destroy!(profile)
        if AiConstants::ProfileKey::ALL.include?(profile.key)
          raise Error, "System default AI profile cannot be deleted: #{profile.key}"
        end

        profile.discard!
      end

      def sync_prices!
        Ai::PriceSyncService.sync!.to_i
      end

      def config
        ensure_defaults!
        chat_profile = Ai::Profile.find_by(key: AiConstants::ProfileKey::CHAT)
        default_prov = chat_profile&.provider.presence || AiConstants::Provider::DEFAULT
        prices_by_provider = Ai::Price.kept.order(:model).group_by(&:provider)
        profile_models_by_provider = Ai::Profile.group(:provider, :model).pluck(:provider, :model).group_by(&:first)
        run_models_by_provider = Ai::Run.group(:provider, :model).pluck(:provider, :model).group_by(&:first)
        all_provider_keys = (AiConstants::Provider::ALL + prices_by_provider.keys + profile_models_by_provider.keys).uniq

        provider_items = all_provider_keys.map do |provider_key|
          active_profile_model = (profile_models_by_provider[provider_key] || []).map(&:last).find(&:present?)
          default_model = active_profile_model || default_model_for_provider(provider_key)
          db_prices = prices_by_provider[provider_key] || []
          price_lookup = {}

          db_prices.each do |price|
            price_lookup[price.model] = {
              input_cost_per_million: price.input_cost_per_million.to_f,
              cached_cost_per_million: price.cached_cost_per_million.to_f,
              output_cost_per_million: price.output_cost_per_million.to_f,
              currency: price.currency
            }
          end

          ordered_model_names = []
          ordered_model_names << default_model if default_model.present?
          (profile_models_by_provider[provider_key] || []).each { |(_, m)| ordered_model_names << m if m.present? }
          db_prices.each { |p| ordered_model_names << p.model }
          (run_models_by_provider[provider_key] || []).each { |(_, m)| ordered_model_names << m if m.present? }
          ordered_model_names.uniq!

          models = ordered_model_names.map do |model_name|
            rates = price_lookup[model_name]
            {
              model: model_name,
              input_cost_per_million: rates ? rates[:input_cost_per_million] : nil,
              cached_cost_per_million: rates ? rates[:cached_cost_per_million] : nil,
              output_cost_per_million: rates ? rates[:output_cost_per_million] : nil,
              currency: rates ? rates[:currency] : AiConstants::Pricing::DEFAULT_CURRENCY
            }
          end

          {
            key: provider_key,
            label: AiConstants::Provider::CONFIG.dig(provider_key, :label) || provider_key.titleize,
            configured: provider_configured?(provider_key),
            default_model: default_model,
            models: models
          }
        end

        {
          default_provider: default_prov,
          default_model: chat_profile&.model.presence || default_model_for_provider(default_prov, chat_profile),
          defaults: {
            temperature: AiConstants::Defaults::TEMPERATURE,
            max_output_tokens: AiConstants::Defaults::MAX_OUTPUT_TOKENS,
            context_max_tokens: AiConstants::Defaults::CONTEXT_MAX_TOKENS,
            history_max_messages: AiConstants::Defaults::HISTORY_MAX_MESSAGES,
            timeout_seconds: AiConstants::Defaults::TIMEOUT_SECONDS
          },
          features: AiConstants::RunFeature::ALL,
          profile_key_presets: DEFAULTS.map { |key, cfg| { key: key, name: cfg[:name] } },
          providers: provider_items
        }
      end

      def resolve!(key)
        normalized_key = key.presence || AiConstants::ProfileKey::CHAT
        profile = Ai::Profile.with_discarded.find_by(key: normalized_key)
        if profile.nil? && AiConstants::ProfileKey::ALL.include?(normalized_key)
          profile = create_default!(normalized_key)
        end
        raise Error, "Unknown AI profile: #{normalized_key}" unless profile
        raise Error, "AI profile is disabled: #{normalized_key}" unless profile.enabled?

        profile
      end

      def create_defaults!
        AiConstants::ProfileKey::ALL.each { |key| create_default!(key) }
      end

      def prompt_for(profile, **values)
        prompt = profile.system_prompt.to_s
        return nil if prompt.blank?

        formatted_values = values.symbolize_keys.transform_values do |val|
          Ai::ToonService.json_to_toon(val)
        end

        interpolated = begin
          prompt % formatted_values
        rescue KeyError
          prompt
        end

        Ai::ToonService.json_to_toon(interpolated)
      end

      private

      def provider_configured?(provider_key)
        key = AiConstants::Provider::CONFIG.dig(provider_key.to_s.downcase, :api_key).to_s.strip
        !key.empty? && !key.downcase.include?("changeme")
      end

      def default_model_for_provider(provider_key, default_profile = nil)
        return default_profile.model if default_profile && default_profile.provider == provider_key && default_profile.model.present?

        existing_profile_model = Ai::Profile.where(provider: provider_key).pick(:model)
        return existing_profile_model if existing_profile_model.present?

        AiConstants::Provider::CONFIG.dig(provider_key.to_s.downcase, :model) || AppConfig::DEEPSEEK_MODEL
      end

      def upsert_model_price!(provider, model, pricing_attrs = {})
        return if provider.blank? || model.blank?

        normalized_provider = provider.to_s.downcase
        normalized_model = model.to_s.strip
        price = Ai::Price.with_discarded.find_or_initialize_by(provider: normalized_provider, model: normalized_model)
        has_explicit_rates = pricing_attrs.values.any?(&:present?)

        if price.new_record?
          price.input_cost_per_million = 0.0
          price.cached_cost_per_million = 0.0
          price.output_cost_per_million = 0.0
          price.currency = AiConstants::Pricing::DEFAULT_CURRENCY
        end

        if has_explicit_rates
          price.input_cost_per_million = pricing_attrs[:input_cost_per_million].to_d if pricing_attrs[:input_cost_per_million].present?
          if pricing_attrs[:cached_cost_per_million].present?
            price.cached_cost_per_million = pricing_attrs[:cached_cost_per_million].to_d
          elsif price.cached_cost_per_million.zero? && price.input_cost_per_million.positive?
            price.cached_cost_per_million = (price.input_cost_per_million * AiConstants::Pricing::DEFAULT_CACHE_DISCOUNT_RATIO.to_d).round(AiConstants::Pricing::DECIMAL_PRECISION)
          end
          price.output_cost_per_million = pricing_attrs[:output_cost_per_million].to_d if pricing_attrs[:output_cost_per_million].present?
        end

        price.discarded_at = nil
        price.save! if price.new_record? || price.changed?
      end

      def ensure_defaults!
        return if Ai::Profile.where(key: AiConstants::ProfileKey::ALL).count >= AiConstants::ProfileKey::ALL.size

        create_defaults!
      end

      def create_default!(key)
        attributes = DEFAULTS.fetch(key)
        default_provider = AiConstants::Provider::DEFAULT
        profile = Ai::Profile.with_discarded.find_or_create_by!(key: key) do |record|
          record.assign_attributes(
            attributes.merge(
              provider: default_provider,
              model: default_model_for_provider(default_provider),
              enabled: true,
              timeout_seconds: AiConstants::Defaults::TIMEOUT_SECONDS
            )
          )
        end
        profile.update!(discarded_at: nil, enabled: true) if profile.discarded?
        profile
      end
    end
  end
end
