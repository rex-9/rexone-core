# app/services/storage_service/client.rb

module StorageService
  class Client
    class << self
      delegate :upload,
               :delete,
               :url,
               :move,
               :copy,
               :exists?,
               :list,
               to: :provider

      def delete_later(identifier, options = {})
        Storage::DeleteJob.perform_later(
          identifier: identifier,
          options: options
        )
      end

      private

      def provider
        @provider ||= initialize_provider
      end

      def initialize_provider
        provider_name = ENV.fetch("STORAGE_PROVIDER", "cloudinary").to_sym

        case provider_name
        when :cloudinary
          Cloudinary.new
        when :local
          Local.new
        else
          raise Error, "Unknown storage provider: #{provider_name}"
        end
      end
    end
  end
end
