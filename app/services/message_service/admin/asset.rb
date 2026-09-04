# app/services/message_service/admin/asset.rb
module MessageService
  module Admin
    class Asset < MessageService::Base
      ASSETS_RETRIEVED = "admin.asset.assets_retrieved".freeze
      ASSET_RETRIEVED = "admin.asset.asset_retrieved".freeze
      ASSET_UPLOADED = "admin.asset.asset_uploaded".freeze
      ASSET_UPDATED = "admin.asset.asset_updated".freeze
      ASSET_DISCARDED = "admin.asset.asset_discarded".freeze
      ASSET_RESTORED = "admin.asset.asset_restored".freeze
      ASSET_DELETED = "admin.asset.asset_deleted".freeze
      DISCARDED_ASSETS_RETRIEVED = "admin.asset.discarded_assets_retrieved".freeze
      NOT_FOUND = "admin.asset.not_found".freeze
      NO_FILE_UPLOADED = "admin.asset.no_file_uploaded".freeze
      FILE_REQUIRED = "admin.asset.file_required".freeze
      SAVE_FAILED = "admin.asset.save_failed".freeze
      STORAGE_UPLOAD_FAILED = "admin.asset.storage_upload_failed".freeze
      UPDATE_FAILED = "admin.asset.update_failed".freeze
      COMPRESSION_ENQUEUED = "admin.asset.compression_enqueued".freeze
      COMPRESSION_NOT_SUPPORTED = "admin.asset.compression_not_supported".freeze
      COMPRESSION_IN_PROGRESS = "admin.asset.compression_in_progress".freeze
      COMPRESSION_COMPLETED = "admin.asset.compression_completed".freeze
      COMPRESSION_FAILED = "admin.asset.compression_failed".freeze
      COMPRESSION_OPTIMAL = "admin.asset.compression_optimal".freeze
      COMPRESSION_ALREADY_OPTIMAL = "admin.asset.compression_already_optimal".freeze
      FILE_SIZE_EXCEEDED = "admin.asset.file_size_exceeded".freeze
      STORAGE_STATS_RETRIEVED = "admin.asset.storage_stats_retrieved".freeze
      RECYCLE_BIN_EMPTIED = "admin.asset.recycle_bin_emptied".freeze
      BATCH_DISCARDED = "admin.asset.batch_discarded".freeze
      BATCH_RESTORED = "admin.asset.batch_restored".freeze
      BATCH_DELETED = "admin.asset.batch_deleted".freeze
      NO_ASSETS_SELECTED = "admin.asset.no_assets_selected".freeze
    end
  end
end
