# app/services/message_service/admin/asset.rb
module MessageService
  module Admin
    class Asset < MessageService::Base
      SCOPE = "admin.asset".freeze

      ASSETS_RETRIEVED = "assets_retrieved".freeze
      ASSET_RETRIEVED = "asset_retrieved".freeze
      ASSET_UPLOADED = "asset_uploaded".freeze
      ASSET_UPDATED = "asset_updated".freeze
      ASSET_DISCARDED = "asset_discarded".freeze
      ASSET_RESTORED = "asset_restored".freeze
      ASSET_DELETED = "asset_deleted".freeze
      DISCARDED_ASSETS_RETRIEVED = "discarded_assets_retrieved".freeze
      NOT_FOUND = "not_found".freeze
      NO_FILE_UPLOADED = "no_file_uploaded".freeze
      FILE_REQUIRED = "file_required".freeze
      SAVE_FAILED = "save_failed".freeze
      STORAGE_UPLOAD_FAILED = "storage_upload_failed".freeze
      UPDATE_FAILED = "update_failed".freeze
    end
  end
end
