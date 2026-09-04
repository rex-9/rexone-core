require "rails_helper"

RSpec.describe StorageService::S3 do
  subject(:provider) { described_class.new }

  let(:client) { Aws::S3::Client.new(stub_responses: true) }

  before do
    stub_const("AppConfig::S3_ENDPOINT", "https://s3.test")
    stub_const("AppConfig::S3_BUCKET", "rexone")
    stub_const("AppConfig::S3_ACCESS_KEY_ID", "access-key")
    stub_const("AppConfig::S3_SECRET_ACCESS_KEY", "secret-key")
    stub_const("AppConfig::S3_PUBLIC_BASE_URL", "")

    # Built eagerly so the real constructor runs before it is stubbed out.
    stubbed_client = client
    allow(Aws::S3::Client).to receive(:new).and_return(stubbed_client)
  end

  def with_audio_tempfile(content: "ID3fake")
    Tempfile.create([ "tts-1", ".mp3" ]) do |file|
      file.binmode
      file.write(content)
      file.rewind
      yield file
    end
  end

  def requests_for(operation)
    client.api_requests.select { |request| request[:operation_name] == operation }
  end

  describe "#upload" do
    it "stores the object under the folder with its extension and content type" do
      result = with_audio_tempfile do |file|
        provider.upload(file, storage_key: "tts_of_message_1", folder: "speech/tts")
      end

      expect(result).to include(
        storage_key: "speech/tts/tts_of_message_1.mp3",
        url: "https://s3.test/rexone/speech/tts/tts_of_message_1.mp3",
        bytes: 7,
        format: "mp3"
      )
      expect(requests_for(:put_object).first[:params]).to include(
        bucket: "rexone",
        key: "speech/tts/tts_of_message_1.mp3",
        body: "ID3fake",
        content_type: "audio/mpeg"
      )
    end

    it "falls back to the default folder and a generated key" do
      result = with_audio_tempfile { |file| provider.upload(file) }

      expect(result[:storage_key]).to match(%r{\Auploads/tts-1.+_\d+\.mp3\z})
    end

    it "echoes the resource type back for callers that clean up after a failed save" do
      result = with_audio_tempfile do |file|
        provider.upload(file, storage_key: "clip", folder: "audio", resource_type: "video")
      end

      expect(result[:resource_type]).to eq("video")
    end

    it "downloads a remote URL before storing it" do
      response = instance_double(Net::HTTPResponse, code: "200", body: "jpegbytes")
      allow(response).to receive(:[]).with("Content-Type").and_return("image/jpeg")
      allow(Net::HTTP).to receive(:start).and_return(response)

      result = provider.upload(
        "https://lh3.googleusercontent.com/a/token=s96-c",
        storage_key: "avatar_of_user_1",
        folder: "avatar"
      )

      expect(result).to include(
        storage_key: "avatar/avatar_of_user_1.jpg",
        url: "https://s3.test/rexone/avatar/avatar_of_user_1.jpg",
        format: "jpg"
      )
      expect(requests_for(:put_object).first[:params]).to include(
        key: "avatar/avatar_of_user_1.jpg",
        body: "jpegbytes",
        content_type: "image/jpeg"
      )
    end

    it "raises when the remote URL cannot be fetched" do
      response = instance_double(Net::HTTPResponse, code: "404", body: "")
      allow(Net::HTTP).to receive(:start).and_return(response)

      expect {
        provider.upload("https://cdn.test/missing.jpg", storage_key: "avatar", folder: "avatar")
      }.to raise_error(StorageService::UploadError, /Could not fetch source URL \(404\)/)
    end

    it "refuses to overwrite an existing object when overwrite is disabled" do
      expect {
        with_audio_tempfile do |file|
          provider.upload(file, storage_key: "clip", folder: "audio", overwrite: false)
        end
      }.to raise_error(StorageService::UploadError, /already exists/)
    end

    it "wraps provider failures in an upload error" do
      client.stub_responses(:put_object, Aws::S3::Errors::ServiceError.new(nil, "storage exploded"))

      expect {
        with_audio_tempfile { |file| provider.upload(file, storage_key: "clip") }
      }.to raise_error(StorageService::UploadError, /storage exploded/)
    end
  end

  describe "#delete" do
    it "removes the object" do
      expect(provider.delete("speech/tts/clip.mp3")).to be(true)
      expect(requests_for(:delete_object).first[:params]).to include(
        bucket: "rexone",
        key: "speech/tts/clip.mp3"
      )
    end

    it "treats a missing key as already deleted" do
      client.stub_responses(:delete_object, Aws::S3::Errors::NoSuchKey.new(nil, "missing"))

      expect(provider.delete("gone.mp3")).to be(true)
    end

    it "raises a delete error on provider failure" do
      client.stub_responses(:delete_object, Aws::S3::Errors::ServiceError.new(nil, "refused"))

      expect { provider.delete("clip.mp3") }.to raise_error(StorageService::DeleteError, /refused/)
    end
  end

  describe "#url" do
    it "builds a path style URL from the endpoint and bucket" do
      expect(provider.url("avatar/a.jpg")).to eq("https://s3.test/rexone/avatar/a.jpg")
    end

    it "prefers the configured public base URL" do
      stub_const("AppConfig::S3_PUBLIC_BASE_URL", "https://cdn.test/")

      expect(provider.url("avatar/a.jpg")).to eq("https://cdn.test/avatar/a.jpg")
    end
  end

  describe "#exists?" do
    it "is true when the object is present" do
      expect(provider.exists?("avatar/a.jpg")).to be(true)
    end

    it "is false when the object is missing" do
      client.stub_responses(:head_object, Aws::S3::Errors::NotFound.new(nil, "missing"))

      expect(provider.exists?("avatar/a.jpg")).to be(false)
    end
  end

  describe "#list" do
    it "maps objects to the shared storage shape" do
      client.stub_responses(
        :list_objects_v2,
        contents: [ { key: "speech/tts/a.mp3", size: 12, last_modified: Time.utc(2026, 1, 1) } ]
      )

      expect(provider.list("speech/tts")).to eq(
        [
          {
            storage_key: "speech/tts/a.mp3",
            url: "https://s3.test/rexone/speech/tts/a.mp3",
            bytes: 12,
            format: "mp3",
            created_at: Time.utc(2026, 1, 1),
            resource_type: nil
          }
        ]
      )
    end

    it "returns an empty list on provider failure" do
      client.stub_responses(:list_objects_v2, Aws::S3::Errors::ServiceError.new(nil, "down"))

      expect(provider.list).to eq([])
    end
  end

  describe "#copy" do
    it "copies the object and reports its size" do
      client.stub_responses(:head_object, { content_length: 42 })

      result = provider.copy("audio/old.mp3", "audio/new.mp3")

      expect(result).to include(
        storage_key: "audio/new.mp3",
        url: "https://s3.test/rexone/audio/new.mp3",
        bytes: 42,
        format: "mp3"
      )
      expect(requests_for(:copy_object).first[:params]).to include(
        bucket: "rexone",
        copy_source: "/rexone/audio/old.mp3",
        key: "audio/new.mp3"
      )
    end
  end

  describe "#move" do
    it "copies then deletes the source" do
      provider.move("audio/old.mp3", "audio/new.mp3")

      expect(requests_for(:copy_object).first[:params]).to include(key: "audio/new.mp3")
      expect(requests_for(:delete_object).first[:params]).to include(key: "audio/old.mp3")
    end
  end

  describe "configuration" do
    it "raises when the bucket is not configured" do
      stub_const("AppConfig::S3_BUCKET", "")

      expect { described_class.new }.to raise_error(
        StorageService::Error,
        /S3_BUCKET/
      )
    end

    it "raises when the endpoint is not configured" do
      stub_const("AppConfig::S3_ENDPOINT", "")

      expect { described_class.new }.to raise_error(StorageService::Error, /S3_ENDPOINT/)
    end
  end
end
