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
               :download,
               :storage_stats,
               to: :provider

      private

      def provider
        @provider ||= initialize_provider
      end

      def initialize_provider
        provider_name = AppConfig::STORAGE_PROVIDER.to_sym

        case provider_name
        when :garage
          Garage.new
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
