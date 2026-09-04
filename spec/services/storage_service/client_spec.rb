require "rails_helper"

RSpec.describe StorageService::Client do
  before { described_class.instance_variable_set(:@provider, nil) }
  after { described_class.instance_variable_set(:@provider, nil) }

  def with_storage_provider(name)
    stub_const("ENV", ENV.to_h.merge("STORAGE_PROVIDER" => name))
  end

  it "selects the S3 provider" do
    stub_const("AppConfig::S3_ENDPOINT", "https://s3.test")
    stub_const("AppConfig::S3_BUCKET", "rexone")
    stub_const("AppConfig::S3_ACCESS_KEY_ID", "key")
    stub_const("AppConfig::S3_SECRET_ACCESS_KEY", "secret")
    with_storage_provider(StorageConstants::Provider::S3)

    expect(described_class.send(:provider)).to be_a(StorageService::S3)
  end

  it "selects the local provider" do
    with_storage_provider(StorageConstants::Provider::LOCAL)

    expect(described_class.send(:provider)).to be_a(StorageService::Local)
  end

  it "raises for an unknown provider" do
    with_storage_provider("ftp")

    expect { described_class.send(:provider) }.to raise_error(
      StorageService::Error,
      /Unknown storage provider: ftp/
    )
  end
end
