# frozen_string_literal: true

# app/services/ai/profile_service.rb
module Ai
  class ProfileService
    Error = Class.new(StandardError)

    DEFAULTS = {
      AiConstants::ProfileKey::CHAT_DEFAULT => {
        name: "Default Chat",
        temperature: 0.7,
        max_output_tokens: 2000,
        context_max_tokens: 8000,
        history_max_messages: 20,
        system_prompt: nil
      },
      AiConstants::ProfileKey::SUMMARIZE => {
        name: "Summarize",
        temperature: 0.5,
        max_output_tokens: 500,
        context_max_tokens: 4000,
        history_max_messages: 1,
        system_prompt: "Summarize the following text concisely."
      },
      AiConstants::ProfileKey::TRANSLATE => {
        name: "Translate",
        temperature: 0.3,
        max_output_tokens: 1000,
        context_max_tokens: 4000,
        history_max_messages: 1,
        system_prompt: "Translate the following text to %{language}. Return only the translation."
      },
      AiConstants::ProfileKey::ANALYZE => {
        name: "Analyze",
        temperature: 0.3,
        max_output_tokens: 500,
        context_max_tokens: 4000,
        history_max_messages: 1,
        system_prompt: "Analyze the following text and provide concise insights."
      }
    }.freeze

    class << self
      def list(params = {})
        scope = Ai::Profile.all
        if params[:status].present? && params[:status] != "all"
          case params[:status]
          when "active", "enabled"
            scope = scope.where(enabled: true)
          when "inactive", "disabled"
            scope = scope.where(enabled: false)
          end
        elsif params[:enabled].present? && params[:enabled] != "all"
          scope = scope.where(enabled: ActiveModel::Type::Boolean.new.cast(params[:enabled]))
        end
        scope = scope.where(provider: params[:provider]) if params[:provider].present? && params[:provider] != "all"
        scope = scope.where(model: params[:model]) if params[:model].present? && params[:model] != "all"
        scope = scope.where("name ILIKE :q OR key ILIKE :q", q: "%#{params[:search]}%") if params[:search].present?
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
        attrs[:provider] = attrs[:provider].presence || AiConstants::Provider::DEEPSEEK
        attrs[:model] = attrs[:model].presence || AppConfig::DEEPSEEK_MODEL
        attrs[:temperature] ||= 0.7
        attrs[:max_output_tokens] ||= 2000
        attrs[:context_max_tokens] ||= 8000
        attrs[:history_max_messages] ||= 20
        attrs[:timeout_seconds] ||= AiConstants::Defaults::TIMEOUT_SECONDS
        attrs[:enabled] = true if attrs[:enabled].nil?

        Ai::Profile.create!(attrs)
      end

      def update!(profile, attributes)
        profile.update!(attributes)
        profile
      end

      def resolve!(key)
        normalized_key = key.presence || AiConstants::ProfileKey::CHAT_DEFAULT
        profile = Ai::Profile.find_by(key: normalized_key)
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

        prompt % values.symbolize_keys
      rescue KeyError
        prompt
      end

      private

      def create_default!(key)
        attributes = DEFAULTS.fetch(key)
        Ai::Profile.find_or_create_by!(key: key) do |profile|
          profile.assign_attributes(
            attributes.merge(
              provider: AiConstants::Provider::DEEPSEEK,
              model: AppConfig::DEEPSEEK_MODEL,
              enabled: true,
              timeout_seconds: AiConstants::Defaults::TIMEOUT_SECONDS
            )
          )
        end
      end
    end
  end
end
