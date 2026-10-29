# frozen_string_literal: true

module Ai
  class SyncModelPricesJob < ApplicationJob
    queue_as :ai

    def perform
      Ai::PriceSyncService.sync!
    end
  end
end
