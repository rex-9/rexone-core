require "rails_helper"

RSpec.describe StorageService::Garage do
  before do
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
end
