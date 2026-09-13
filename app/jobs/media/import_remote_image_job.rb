module Media
  class ImportRemoteImageJob < ApplicationJob
    queue_as :media

    limits_concurrency(
      to: 1,
      key: ->(asset_id:, **) { MediaConstants::Processing.concurrency_key(asset_id) },
      duration: 30.minutes
    )

    retry_on StorageService::Error, RestClient::Exception,
             wait: :polynomially_longer, attempts: 3 do |job, _error|
      asset_id = job.arguments.first.with_indifferent_access[:asset_id]
      Asset.find_by(id: asset_id)&.mark_failed!
    end
    discard_on ActiveRecord::RecordNotFound

    def perform(asset_id:, source_url:, storage_key:)
      asset = Asset.find(asset_id)
      return if asset.storage_key.present?

      asset.mark_processing!
      response = RestClient::Request.execute(method: :get, url: source_url)
      extension = extension_for(response.headers[:content_type])
      target_key = AssetConstants::AssetName.with_extension(storage_key, extension)

      Tempfile.create([ "google_avatar", ".#{extension}" ], binmode: true) do |file|
        file.write(response.body)
        file.flush
        result = StorageService::Client.upload(
          file.path,
          storage_key: target_key,
          resource_type: AssetConstants::AssetFormat::IMAGE,
          content_type: response.headers[:content_type]
        )
        asset.update!(
          name: result[:storage_key],
          url: result[:url],
          storage_key: result[:storage_key],
          extension: result[:format].presence || extension,
          size_bytes: result[:bytes] || file.size,
          status: MediaConstants::Status::READY
        )
      end
    rescue StandardError
      asset&.mark_failed!
      raise
    end

    private

    def extension_for(content_type)
      Rack::Mime::MIME_TYPES.invert.fetch(content_type.to_s.split(";").first, ".jpg").delete(".")
    end
  end
end
