class Storage::DeleteJob < ApplicationJob
  queue_as :storage

  retry_on StorageService::Error,
           wait: :polynomially_longer,
           attempts: 5

  def perform(identifier:, options: {})
    StorageService::Client.delete(identifier, options.symbolize_keys)
  end
end
