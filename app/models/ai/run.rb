# frozen_string_literal: true

module Ai
  class Run < ApplicationRecord
    self.table_name = "ai_runs"

    belongs_to :profile, class_name: "Ai::Profile", foreign_key: :ai_profile_id
    belongs_to :user
    belongs_to :chat_message, class_name: "Chat::Message", optional: true

    validates :feature, presence: true, inclusion: { in: AiConstants::RunFeature::ALL }
    validates :provider, presence: true, inclusion: { in: AiConstants::Provider::ALL }
    validates :model, presence: true
    validates :status, presence: true, inclusion: { in: AiConstants::RunStatus::ALL }
  end
end
