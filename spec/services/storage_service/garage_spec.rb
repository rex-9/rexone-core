require "rails_helper"

RSpec.describe StorageService::Garage do
  before do
    unless defined?(Aws::S3::Client)
      stub_const("Aws::S3::Client", Class.new { def initialize(*_args, **_kwargs); end })
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
    it "constructs standard path-style url using public endpoint and bucket" do
      expect(adapter.url("uploads/test.png")).to eq("http://localhost:3900/rexone/uploads/test.png")
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
end
