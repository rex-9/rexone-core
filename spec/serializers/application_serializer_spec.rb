# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationSerializer do
  let(:dummy_serializer) do
    Class.new(described_class) do
      set_type :dummy_item
      attributes :name, :role
    end
  end

  let(:item1) { double("Item1", id: "1", name: "Alpha", role: "admin") }
  let(:item2) { double("Item2", id: "2", name: "Beta", role: "member") }

  describe ".record" do
    it "serializes a single record data envelope" do
      result = dummy_serializer.record(item1)
      expect(result[:id]).to eq("1")
      expect(result[:type]).to eq(:dummy_item)
      expect(result[:attributes][:name]).to eq("Alpha")
    end

    it "returns nil for nil record" do
      expect(dummy_serializer.record(nil)).to be_nil
    end
  end

  describe ".collection" do
    it "serializes a collection of records" do
      result = dummy_serializer.collection([item1, item2])
      expect(result.size).to eq(2)
      expect(result.first[:id]).to eq("1")
      expect(result.last[:id]).to eq("2")
    end

    it "returns empty array for blank collection" do
      expect(dummy_serializer.collection([])).to eq([])
      expect(dummy_serializer.collection(nil)).to eq([])
    end
  end

  describe ".record_attributes" do
    it "extracts attributes hash directly" do
      result = dummy_serializer.record_attributes(item1)
      expect(result[:id]).to eq("1")
      expect(result[:name]).to eq("Alpha")
      expect(result[:role]).to eq("admin")
    end

    it "returns nil for nil record" do
      expect(dummy_serializer.record_attributes(nil)).to be_nil
    end
  end

  describe ".collection_attributes" do
    it "extracts array of attribute hashes" do
      result = dummy_serializer.collection_attributes([item1, item2])
      expect(result).to eq([
        { id: "1", name: "Alpha", role: "admin" },
        { id: "2", name: "Beta", role: "member" }
      ])
    end

    it "returns empty array for blank collection" do
      expect(dummy_serializer.collection_attributes([])).to eq([])
      expect(dummy_serializer.collection_attributes(nil)).to eq([])
    end
  end

  describe ".collection_pagy" do
    let(:pagy) do
      double(
        "Pagy",
        page: 1,
        pages: 3,
        count: 25,
        limit: 10,
        next: 2,
        previous: nil
      )
    end

    it "serializes collection with standardized pagination metadata" do
      result = dummy_serializer.collection_pagy([item1, item2], pagy)

      expect(result[:data]).to be_an(Array)
      expect(result[:data].size).to eq(2)
      expect(result[:data].first[:id]).to eq("1")

      expect(result[:meta][:pagination]).to eq({
        current_page: 1,
        total_pages: 3,
        total_count: 25,
        limit: 10,
        next_page: 2,
        prev_page: nil
      })
    end
  end
end
