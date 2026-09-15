# frozen_string_literal: true

class Chat::ProcessMessageJob < ApplicationJob
  queue_as :ai

  limits_concurrency(
    to: 1,
    key: ->(message_id) { message_id },
    duration: 30.minutes
  )

  retry_on Ai::Providers::Error,
           wait: :polynomially_longer,
           attempts: 5 do |job, error|
    Chat::MessageService.fail_ai_response!(job.arguments.first, error)
  end

  discard_on ActiveRecord::RecordNotFound

  def perform(message_id)
    Chat::MessageService.process_ai_response!(message_id)
  end
end
