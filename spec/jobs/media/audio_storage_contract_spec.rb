require "rails_helper"

RSpec.describe "Audio storage contract", type: :integration do
  class ContractLocalStorage < StorageService::Local
    def upload(file, options = {})
      super.merge(url: "https://assets.example.test/#{options[:storage_key]}")
    end
  end

  before do
    @storage_path = Dir.mktmpdir("audio_storage_contract")
    stub_const("AppConfig::LOCAL_STORAGE_PATH", @storage_path)
    allow(StorageService::Client).to receive(:provider).and_return(ContractLocalStorage.new)
  end

  after { FileUtils.rm_rf(@storage_path) }

  it "stores format-changing output under the matching key and removes the old object" do
    original_path = File.join(@storage_path, "source.wav")
    File.binwrite(original_path, "RIFF" + ("original-audio" * 1_000))
    upload = StorageService::Client.upload(original_path, storage_key: "dev/user/audio.wav")
    asset = create(:asset, name: upload[:storage_key], url: upload[:url], storage_key: upload[:storage_key], extension: "wav", format: AssetConstants::AssetFormat::AUDIO, size_bytes: upload[:bytes])
    converted_fixture = Rails.root.join("spec/fixtures/files/clip.m4a").to_s
    allow(MediaService::AudioCompressor).to receive(:compress).and_return(converted_fixture)

    Media::CompressMediaJob.perform_now(asset_id: asset.id)

    asset.reload
    expect(asset.storage_key).to end_with(".m4a")
    expect(asset.extension).to eq("m4a")
    expect(StorageService::Client.exists?(asset.storage_key)).to be(true)
    expect(StorageService::Client.exists?("dev/user/audio.wav")).to be(false)
    expect(StorageService::Client.download(asset.storage_key)).to eq(File.binread(converted_fixture))
  end

  it "uses one concurrency lock for every processor targeting the same asset" do
    asset_id = SecureRandom.uuid
    jobs = [ Media::CompressMediaJob, Media::ConvertImageJob, Media::GenerateVideoThumbnailJob ]

    expect(jobs.map { |job| job.concurrency_key.call(asset_id: asset_id) }.uniq).to eq([ MediaConstants::Processing.concurrency_key(asset_id) ])
  end
end
