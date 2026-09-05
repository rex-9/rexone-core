# app/jobs/data_sync_job.rb
# frozen_string_literal: true

class DataSyncJob < ApplicationJob
  queue_as :default

  def perform(sync_type = "all", **_options)
    case sync_type.to_s
    when "all"
      DataSyncService.sync_all!
    else
      Rails.logger.warn("[DataSyncJob] Unknown or retired sync_type: #{sync_type}")
    end
  end
end
