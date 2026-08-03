# app/services/storage_service/error.rb

module StorageService
  class Error < StandardError; end
  class NotFoundError < Error; end
  class UploadError < Error; end
  class DeleteError < Error; end
end
