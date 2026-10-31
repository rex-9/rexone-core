# frozen_string_literal: true

module Ai
  class Profile < ApplicationRecord
    self.table_name = "ai_profiles"

    has_many :runs, class_name: "Ai::Run", foreign_key: :ai_profile_id, dependent: :restrict_with_error
    has_many :chat_messages, class_name: "Chat::Message", foreign_key: :ai_profile_id, dependent: :nullify

    validates :key, presence: true, uniqueness: true,
                    format: { with: /\A[a-z0-9_]+\z/, message: "must contain only lowercase letters, numbers, and underscores" }
    validates :name, presence: true
    validates :provider, presence: true, inclusion: { in: AiConstants::Provider::ALL }
    validates :model, presence: true
    validates :temperature, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }
    validates :max_output_tokens, :context_max_tokens, :history_max_messages, :timeout_seconds,
              numericality: { only_integer: true, greater_than: 0 }

    has_metadata Ai::Profile::Settings, attribute_name: :settings

    scope :enabled, -> { where(enabled: true) }

    before_discard :disable

    def enabled?
      super && !discarded?
    end

    private

    def disable
      self.enabled = false
    end
  end
end
