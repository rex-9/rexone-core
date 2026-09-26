# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssetSerializer do
  let(:user) { create(:user) }
  let(:parent_asset) do
    create(
      :asset,
      name: "videos/intro.mp4",
      title: "Intro Video",
      type: AssetConstants::AssetType::GENERAL,
      format: AssetConstants::AssetFormat::VIDEO,
      storage_key: "videos/intro.mp4",
      creator: user
    )
  end
  let(:thumbnail) do
    create(
      :asset,
      name: "images/thumb.jpg",
      title: "Thumbnail",
      type: AssetConstants::AssetType::THUMBNAIL,
      storage_key: "images/thumb.jpg",
      parent_asset_id: parent_asset.id,
      creator: user
    )
  end
  let(:subtitle) do
    create(
      :asset,
      name: "subtitles/en.srt",
      title: "English Subtitle",
      type: AssetConstants::AssetType::SUBTITLE,
      storage_key: "subtitles/en.srt",
      parent_asset_id: parent_asset.id,
      creator: user
    )
  end

  before do
    thumbnail
    subtitle
    parent_asset.reload
  end

  it "serializes core asset attributes and nested children through canonical serializers" do
    serialized = described_class.record_attributes(parent_asset)

    expect(serialized).to include(:id, :name, :title, :type, :children, :url, :display_name)
    expect(serialized[:children]).to be_a(Hash)
    expect(serialized[:children][:thumbnail]).to be_a(Hash)
    expect(serialized[:children][:thumbnail][:id]).to eq(thumbnail.id)
    expect(serialized[:children][:thumbnail][:title]).to eq("Thumbnail")

    expect(serialized[:children][:subtitles]).to be_an(Array)
    expect(serialized[:children][:subtitles].first[:id]).to eq(subtitle.id)
    expect(serialized[:children][:subtitles].first[:title]).to eq("English Subtitle")
  end

  it "handles empty collection and nil record gracefully" do
    expect(described_class.record_attributes(nil)).to be_nil
    expect(described_class.collection_attributes([])).to eq([])
  end
end
