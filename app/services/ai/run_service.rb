# frozen_string_literal: true

# app/services/ai/run_service.rb
module Ai
  class RunService
    Error = Class.new(StandardError)

    class << self
      def list(params = {})
        scope = Ai::Run.includes(:profile, :user, :chat_message)
        scope = scope.where(feature: params[:feature]) if params[:feature].present? && params[:feature] != "all"
        scope = scope.where(status: params[:status]) if params[:status].present? && params[:status] != "all"
        scope = scope.where(provider: params[:provider]) if params[:provider].present? && params[:provider] != "all"
        scope = scope.where(model: params[:model]) if params[:model].present? && params[:model] != "all"
        scope = scope.where(ai_profile_id: params[:profile_id]) if params[:profile_id].present?
        scope = scope.where(user_id: params[:user_id]) if params[:user_id].present?
        if params[:search].present?
          scope = scope.where("ai_runs.model ILIKE :q OR ai_runs.feature ILIKE :q", q: "%#{params[:search]}%")
        end
        scope
      end

      def find(id)
        Ai::Run.includes(:profile, :user, :chat_message).find(id)
      end

      def execute_chat(user:, feature:, profile_key:, messages:, chat_message: nil, prompt_values: {}, metadata: {})
        profile = Ai::ProfileService.resolve!(profile_key)
        prepared_messages = with_system_prompt(profile, messages, prompt_values)
        llm_messages = Ai::ToonService.prepare_messages_for_llm(prepared_messages)
        run = create_run!(user, profile, feature, llm_messages, chat_message, metadata)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        result = Ai::Providers::Client.chat(
          provider: profile.provider,
          messages: llm_messages,
          model: profile.model,
          temperature: profile.temperature.to_f,
          max_tokens: profile.max_output_tokens,
          timeout_seconds: profile.timeout_seconds
        )

        latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        choice = result.dig(AiConstants::ResponseKeys::CHOICES, 0) || {}
        message_obj = choice[AiConstants::ResponseKeys::MESSAGE] || {}
        output = message_obj[AiConstants::ResponseKeys::CONTENT].to_s

        if result[:error].present?
          fail_run!(run, result[:error], latency_ms, result)
        elsif output.blank?
          finish_reason = choice[AiConstants::ResponseKeys::FINISH_REASON]
          error_msg = if finish_reason == AiConstants::ResponseKeys::LENGTH
            "AI provider token limit exceeded during generation (finish_reason: length)"
          else
            ::MessageService::Ai.t(::MessageService::Ai::NO_RESPONSE)
          end
          fail_run!(run, error_msg, latency_ms, result)
          result[:error] = error_msg
        else
          converted_output = Ai::ToonService.toon_to_json(output)
          message_obj[AiConstants::ResponseKeys::CONTENT] = converted_output
          complete_run!(run, result, latency_ms)
        end
        result
      rescue StandardError => error
        latency_ms = started_at ? ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round : nil
        fail_run!(run, error.message, latency_ms) if run
        raise
      end

      private

      def with_system_prompt(profile, messages, prompt_values)
        prompt = Ai::ProfileService.prompt_for(profile, **prompt_values)
        return messages if prompt.blank?
        return messages if messages.any? { |msg| msg[:role] == AiConstants::ChatRole::SYSTEM || msg[AiConstants::ResponseKeys::ROLE] == AiConstants::ChatRole::SYSTEM }

        [ { role: AiConstants::ChatRole::SYSTEM, content: prompt }, *messages ]
      end

      def create_run!(user, profile, feature, messages, chat_message, metadata)
        Ai::Run.create!(
          user: user,
          profile: profile,
          chat_message: chat_message,
          feature: feature,
          provider: profile.provider,
          model: profile.model,
          status: AiConstants::RunStatus::PROCESSING,
          input_messages_count: messages.size,
          input_chars: messages.sum { |msg| msg[:content].to_s.length + msg[AiConstants::ResponseKeys::CONTENT].to_s.length },
          metadata: metadata
        )
      end

      def complete_run!(run, result, latency_ms)
        usage = result[AiConstants::UsageKeys::USAGE] || {}
        choice = result.dig(AiConstants::ResponseKeys::CHOICES, 0) || {}
        message_obj = choice[AiConstants::ResponseKeys::MESSAGE] || {}
        output = message_obj[AiConstants::ResponseKeys::CONTENT].to_s
        prompt_tokens = usage[AiConstants::UsageKeys::PROMPT_TOKENS].to_i
        completion_tokens = usage[AiConstants::UsageKeys::COMPLETION_TOKENS].to_i
        cached_tokens = extract_cached_tokens(usage)

        cost = Ai::CostCalculator.calculate(
          provider: run.provider,
          model: run.model,
          prompt_tokens: prompt_tokens,
          completion_tokens: completion_tokens,
          cached_tokens: cached_tokens
        )

        run.update!(
          status: AiConstants::RunStatus::COMPLETED,
          output_chars: output.length,
          prompt_tokens: prompt_tokens,
          completion_tokens: completion_tokens,
          total_tokens: usage[AiConstants::UsageKeys::TOTAL_TOKENS] || (prompt_tokens + completion_tokens),
          cost: cost,
          latency_ms: latency_ms,
          error: nil
        )
      end

      def fail_run!(run, error, latency_ms, result = nil)
        usage = result ? (result[AiConstants::UsageKeys::USAGE] || {}) : {}
        prompt_tokens = usage[AiConstants::UsageKeys::PROMPT_TOKENS].to_i
        completion_tokens = usage[AiConstants::UsageKeys::COMPLETION_TOKENS].to_i
        cached_tokens = extract_cached_tokens(usage)

        cost = if prompt_tokens.positive? || completion_tokens.positive?
          Ai::CostCalculator.calculate(
            provider: run.provider,
            model: run.model,
            prompt_tokens: prompt_tokens,
            completion_tokens: completion_tokens,
            cached_tokens: cached_tokens
          )
        else
          0.0
        end

        run.update!(
          status: AiConstants::RunStatus::FAILED,
          output_chars: 0,
          prompt_tokens: prompt_tokens,
          completion_tokens: completion_tokens,
          total_tokens: usage[AiConstants::UsageKeys::TOTAL_TOKENS] || (prompt_tokens + completion_tokens),
          cost: cost,
          latency_ms: latency_ms,
          error: error
        )
      end

      def extract_cached_tokens(usage)
        return 0 unless usage.is_a?(Hash)

        usage.dig(AiConstants::UsageKeys::PROMPT_TOKENS_DETAILS, AiConstants::UsageKeys::CACHED_TOKENS) ||
          usage[AiConstants::UsageKeys::CACHE_READ_INPUT_TOKENS] ||
          usage.dig(AiConstants::UsageKeys::USAGE_METADATA, AiConstants::UsageKeys::CACHED_CONTENT_TOKEN_COUNT) ||
          usage[AiConstants::UsageKeys::CACHED_TOKENS] ||
          0
      end
    end
  end
end
