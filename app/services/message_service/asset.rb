module MessageService
  class Asset < Base
    FETCHED = "asset.fetched"
    FETCHED_ONE = "asset.fetched_one"
    NO_FILE_UPLOADED = "asset.no_file_uploaded"
    FILE_REQUIRED = "asset.file_required"
    UPLOADED = "asset.uploaded"
    SAVE_FAILED = "asset.save_failed"
    STORAGE_UPLOAD_FAILED = "asset.storage_upload_failed"
    CREATED = "asset.created"
    CREATE_FAILED = "asset.create_failed"
    UPDATED = "asset.updated"
    UPDATE_FAILED = "asset.update_failed"
    DELETED = "asset.deleted"
    DELETE_FAILED = "asset.delete_failed"
    URL_REFRESHED = "asset.url_refreshed"
    URL_REFRESH_FAILED = "asset.url_refresh_failed"
    STORAGE_LISTED = "asset.storage_listed"
    STORAGE_LIST_FAILED = "asset.storage_list_failed"
    NOT_FOUND = "asset.not_found"
  end
end
