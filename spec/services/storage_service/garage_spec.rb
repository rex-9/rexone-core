require "rails_helper"

RSpec.describe StorageService::Garage do
  before do
    stub_const("AppConfig::S3_FOLDER_PREFIX", nil)
    unless defined?(Aws::S3::Client)
      stub_const("Aws::S3::Client", Class.new { def initialize(*_args, **_kwargs); end })
      stub_const("Aws::S3::Presigner", Class.new { def initialize(*_args, **_kwargs); end })
      stub_const("Aws::S3::Errors::ServiceError", Class.new(StandardError))
      stub_const("Aws::S3::Errors::NotFound", Class.new(StandardError))
    end
    allow_any_instance_of(described_class).to receive(:require).with("aws-sdk-s3")
  end

  let(:s3_client) { double("Aws::S3::Client") }
  subject(:adapter) do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    described_class.new
  end

  describe "#url" do
    it "generates a presigned URL using the public endpoint and bucket" do
      presigner = double("Aws::S3::Presigner")
      allow(Aws::S3::Presigner).to receive(:new).with(client: s3_client).and_return(presigner)
      allow(presigner).to receive(:presigned_url).with(
        :get_object,
        bucket: "rexone",
        key: "uploads/test.png",
        expires_in: 7.days.to_i,
        response_content_type: "image/png"
      ).and_return("http://localhost:3100/rexone/uploads/test.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=xyz")

      expect(adapter.url("uploads/test.png")).to eq("http://localhost:3100/rexone/uploads/test.png?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=xyz")
    end


    it "derives the signed response MIME type from a format-changing audio key" do
      presigner = double("Aws::S3::Presigner")
      allow(Aws::S3::Presigner).to receive(:new).with(client: s3_client).and_return(presigner)
      expect(presigner).to receive(:presigned_url).with(
        :get_object,
        bucket: "rexone",
        key: "uploads/audio.m4a",
        expires_in: 7.days.to_i,
        response_content_type: "audio/mp4a-latm"
      ).and_return("http://localhost:3100/rexone/uploads/audio.m4a?sig=123")

      expect(adapter.url("uploads/audio.m4a")).to include("audio.m4a")
    end
  end

  describe "#playback_url" do
    it "creates a progressive presigned GET URL for inline media playback" do
      asset = build(
        :asset,
        storage_key: "uploads/video.mp4",
        extension: "mp4",
        format: "video"
      )
      presigner = double("Aws::S3::Presigner")
      allow(Aws::S3::Presigner).to receive(:new).with(client: s3_client).and_return(presigner)
      expect(presigner).to receive(:presigned_url).with(
        :get_object,
        bucket: "rexone",
        key: "uploads/video.mp4",
        expires_in: 3600,
        response_content_type: "video/mp4",
        response_content_disposition: "inline"
      ).and_return("http://localhost:3100/rexone/uploads/video.mp4?X-Amz-Signature=xyz")

      travel_to Time.zone.parse("2026-09-14 10:00:00 UTC") do
        expect(adapter.playback_url(asset, expires_in: 3600)).to eq(
          type: "progressive",
          url: "http://localhost:3100/rexone/uploads/video.mp4?X-Amz-Signature=xyz",
          expires_at: Time.zone.parse("2026-09-14 11:00:00 UTC")
        )
      end
    end

    it "uses the configured public client when presigning playback URLs" do
      public_client = double("Public S3 Client")
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client, public_client)
      adapter = described_class.new
      presigner = double("Aws::S3::Presigner", presigned_url: "http://localhost:3100/rexone/uploads/audio.mp3?sig=123")
      allow(Aws::S3::Presigner).to receive(:new).with(client: public_client).and_return(presigner)
      asset = build(:asset, storage_key: "uploads/audio.mp3", extension: "mp3", format: "audio")

      expect(adapter.playback_url(asset, expires_in: 120)[:url]).to include("audio.mp3")
    end
  end

  describe "#delete" do
    it "deletes object from bucket and returns true" do
      allow(s3_client).to receive(:delete_object).with(bucket: "rexone", key: "uploads/test.png")
      expect(adapter.delete("uploads/test.png")).to be(true)
    end
  end

  describe "#exists?" do
    it "returns true when head_object succeeds" do
      allow(s3_client).to receive(:head_object).with(bucket: "rexone", key: "uploads/test.png")
      expect(adapter.exists?("uploads/test.png")).to be(true)
    end
  end

  describe "#download" do
    it "streams to destination_path when provided" do
      expect(s3_client).to receive(:get_object).with(
        bucket: "rexone",
        key: "uploads/test.png",
        response_target: "/tmp/dest.png"
      )
      expect(adapter.download("uploads/test.png", "/tmp/dest.png")).to eq("/tmp/dest.png")
    end

    it "returns body content when destination_path is omitted" do
      body_mock = double("Body", read: "file-content")
      response_mock = double("Response", body: body_mock)
      expect(s3_client).to receive(:get_object).with(
        bucket: "rexone",
        key: "uploads/test.png"
      ).and_return(response_mock)
      expect(adapter.download("uploads/test.png")).to eq("file-content")
    end
  end

  describe "#upload" do
    let(:file_double) { double("File", size: 1024, original_filename: "photo.jpg") }

    it "uploads file and returns storage metadata" do
      expect(s3_client).to receive(:put_object).with(
        bucket: "rexone",
        key: "user/1/photo.jpg",
        body: file_double,
        content_type: "image/jpeg"
      )
      presigner = double("Aws::S3::Presigner")
      allow(Aws::S3::Presigner).to receive(:new).with(client: adapter.public_client).and_return(presigner)
      allow(presigner).to receive(:presigned_url).and_return("http://localhost:3100/rexone/user/1/photo.jpg")

      result = adapter.upload(file_double, storage_key: "user/1/photo.jpg")
      expect(result[:storage_key]).to eq("user/1/photo.jpg")
      expect(result[:bytes]).to eq(1024)
    end
  end

  describe "#storage_stats" do
    it "reports Garage usage for every environment partition" do
      allow(adapter).to receive(:require).with("net/http")
      allow(adapter).to receive(:require).with("json")
      allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)

      partition_objects = {
        "dev/" => [ double("Object", size: 100), double("Object", size: 200) ],
        "uat/" => [ double("Object", size: 300) ],
        "prod/" => [ double("Object", size: 400), double("Object", size: 500) ]
      }
      create(:asset, storage_key: "dev/images/one.png", size_bytes: 125)
      create(:asset, storage_key: "prod/images/two.png", size_bytes: 500)
      allow(s3_client).to receive(:list_objects_v2) do |prefix:, **|
        double(
          "ListOutput",
          contents: partition_objects.fetch(prefix),
          is_truncated: false
        )
      end

      stats = adapter.storage_stats

      expect(stats[:partitions]).to eq(
        "dev" => { bytes: 300, objects: 2 },
        "uat" => { bytes: 300, objects: 1 },
        "prod" => { bytes: 900, objects: 2 }
      )
      expect(stats[:tracked_partitions]).to eq(
        "dev" => { bytes: 125, objects: 1 },
        "uat" => { bytes: 0, objects: 0 },
        "prod" => { bytes: 500, objects: 1 }
      )
    end
  end

  context "when S3_FOLDER_PREFIX is configured" do
    before do
      stub_const("AppConfig::S3_FOLDER_PREFIX", "prod")
    end

    let(:file_double) { double("File", size: 512, original_filename: "avatar.png") }

    it "automatically prefixes uploaded storage_key with the folder" do
      expect(s3_client).to receive(:put_object).with(
        bucket: "rexone",
        key: "prod/user/1/avatar.png",
        body: file_double,
        content_type: "image/png"
      )
      presigner = double("Aws::S3::Presigner")
      allow(Aws::S3::Presigner).to receive(:new).with(client: adapter.public_client).and_return(presigner)
      allow(presigner).to receive(:presigned_url).and_return("http://localhost:3100/rexone/prod/user/1/avatar.png")

      result = adapter.upload(file_double, storage_key: "user/1/avatar.png")
      expect(result[:storage_key]).to eq("prod/user/1/avatar.png")
    end

    it "does not double-prefix if storage_key already begins with prefix" do
      expect(s3_client).to receive(:put_object).with(
        bucket: "rexone",
        key: "prod/user/1/avatar.png",
        body: file_double,
        content_type: "image/png"
      )
      presigner = double("Aws::S3::Presigner")
      allow(Aws::S3::Presigner).to receive(:new).with(client: adapter.public_client).and_return(presigner)
      allow(presigner).to receive(:presigned_url).and_return("http://localhost:3100/rexone/prod/user/1/avatar.png")

      result = adapter.upload(file_double, storage_key: "prod/user/1/avatar.png")
      expect(result[:storage_key]).to eq("prod/user/1/avatar.png")
    end

    it "preserves an explicit key from another environment partition" do
      expect(s3_client).to receive(:head_object).with(bucket: "rexone", key: "uat/user/1/avatar.png")

      expect(adapter.exists?("uat/user/1/avatar.png")).to be(true)
    end

    it "prefixes delete calls" do
      expect(s3_client).to receive(:delete_object).with(bucket: "rexone", key: "prod/user/1/avatar.png")
      expect(adapter.delete("user/1/avatar.png")).to be(true)
    end

    it "prefixes list queries" do
      list_output = double("ListOutput", contents: [
        double("Object", key: "prod/user/1/avatar.png", size: 512, last_modified: Time.now)
      ])
      expect(s3_client).to receive(:list_objects_v2).with(
        bucket: "rexone",
        prefix: "prod/user",
        max_keys: 100
      ).and_return(list_output)
      allow(adapter).to receive(:url).with("prod/user/1/avatar.png").and_return("http://localhost:3100/rexone/prod/user/1/avatar.png")

      results = adapter.list("user")
      expect(results.first[:storage_key]).to eq("prod/user/1/avatar.png")
    end
  end

  context "when in development environment with 'dev' prefix" do
    before do
      stub_const("AppConfig::S3_FOLDER_PREFIX", "dev")
    end

    let(:file_double) { double("File", size: 1024, original_filename: "banner.jpg") }

    it "uploads files to the dev/ folder" do
      expect(s3_client).to receive(:put_object).with(
        bucket: "rexone",
        key: "dev/uploads/banner.jpg",
        body: file_double,
        content_type: "image/jpeg"
      )
      presigner = double("Aws::S3::Presigner")
      allow(Aws::S3::Presigner).to receive(:new).with(client: adapter.public_client).and_return(presigner)
      allow(presigner).to receive(:presigned_url).and_return("http://localhost:3100/rexone/dev/uploads/banner.jpg")

      result = adapter.upload(file_double, storage_key: "uploads/banner.jpg")
      expect(result[:storage_key]).to eq("dev/uploads/banner.jpg")
    end

    it "presigns URLs with the dev/ folder" do
      presigner = double("Aws::S3::Presigner")
      allow(Aws::S3::Presigner).to receive(:new).with(client: adapter.public_client).and_return(presigner)
      expect(presigner).to receive(:presigned_url).with(
        :get_object,
        bucket: "rexone",
        key: "dev/photos/test.jpg",
        expires_in: 7.days.to_i,
        response_content_type: "image/jpeg"
      ).and_return("http://localhost:3100/rexone/dev/photos/test.jpg?sig=123")

      expect(adapter.url("photos/test.jpg")).to eq("http://localhost:3100/rexone/dev/photos/test.jpg?sig=123")
    end

    it "does not double-prefix when URL already contains dev/" do
      presigner = double("Aws::S3::Presigner")
      allow(Aws::S3::Presigner).to receive(:new).with(client: adapter.public_client).and_return(presigner)
      expect(presigner).to receive(:presigned_url).with(
        :get_object,
        bucket: "rexone",
        key: "dev/photos/test.jpg",
        expires_in: 7.days.to_i,
        response_content_type: "image/jpeg"
      ).and_return("http://localhost:3100/rexone/dev/photos/test.jpg?sig=123")

      expect(adapter.url("dev/photos/test.jpg")).to eq("http://localhost:3100/rexone/dev/photos/test.jpg?sig=123")
    end

    it "checks existence with dev/ prefix" do
      expect(s3_client).to receive(:head_object).with(bucket: "rexone", key: "dev/uploads/test.png")
      expect(adapter.exists?("uploads/test.png")).to be(true)
    end

    it "downloads objects with dev/ prefix" do
      expect(s3_client).to receive(:get_object).with(
        bucket: "rexone",
        key: "dev/uploads/test.png",
        response_target: "/tmp/dest.png"
      )
      expect(adapter.download("uploads/test.png", "/tmp/dest.png")).to eq("/tmp/dest.png")
    end

    it "copies objects with dev/ prefix on both source and destination" do
      expect(s3_client).to receive(:copy_object).with(
        bucket: "rexone",
        copy_source: "rexone/dev/src.png",
        key: "dev/dst.png"
      )
      head_double = double("HeadObject", content_length: 2048)
      expect(s3_client).to receive(:head_object).with(bucket: "rexone", key: "dev/dst.png").and_return(head_double)
      allow(adapter).to receive(:url).with("dev/dst.png").and_return("http://localhost:3100/rexone/dev/dst.png")

      result = adapter.copy("src.png", "dst.png")
      expect(result[:storage_key]).to eq("dev/dst.png")
      expect(result[:bytes]).to eq(2048)
    end
  end

  context "when AppConfig::S3_FOLDER_PREFIX is undefined" do
    before do
      hide_const("AppConfig::S3_FOLDER_PREFIX")
    end

    it "falls back gracefully to nil without raising NameError" do
      expect(adapter.send(:folder_prefix)).to be_nil
      expect(adapter.send(:apply_prefix, "my_file.png")).to eq("my_file.png")
    end
  end

  context "when AppConfig::S3_FOLDER_PREFIX is configured" do
    before do
      stub_const("AppConfig::S3_FOLDER_PREFIX", "custom_folder")
    end

    it "uses AppConfig::S3_FOLDER_PREFIX" do
      expect(adapter.send(:folder_prefix)).to eq("custom_folder")
      expect(adapter.send(:apply_prefix, "my_file.png")).to eq("custom_folder/my_file.png")
    end
  end
end
