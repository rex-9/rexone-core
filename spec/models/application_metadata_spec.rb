# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationMetadata, type: :model do
  let(:test_metadata_class) do
    Class.new(ApplicationMetadata) do
      attribute :code, :string
      attribute :count, :integer
      attribute :active, :boolean
    end
  end

  describe "serialization and formatting" do
    it "exports clean compacted hash with string keys via #to_h and #to_hash" do
      meta = test_metadata_class.new(code: "promo", count: 3)
      expect(meta.to_h).to eq("code" => "promo", "count" => 3)
      expect(meta.to_hash).to eq("code" => "promo", "count" => 3)
    end

    it "safely serializes to json via JSON.generate and to_json without object pointer strings" do
      meta = test_metadata_class.new(code: "alpha", count: 1)
      hash_with_meta = { data: meta }

      direct_json = meta.to_json
      expect(JSON.parse(direct_json)).to eq("code" => "alpha", "count" => 1)

      generated_json = JSON.generate(hash_with_meta)
      expect(generated_json).not_to include("#<")
      expect(JSON.parse(generated_json)).to eq("data" => { "code" => "alpha", "count" => 1 })
    end

    it "exports valid as_json representation" do
      meta = test_metadata_class.new(code: "beta", count: 2)
      expect(meta.as_json).to eq("code" => "beta", "count" => 2)
    end
  end

  describe "hash delegation" do
    it "delegates keys, values, slice, except, and each to #to_h" do
      meta = test_metadata_class.new(code: "gamma", count: 5)
      expect(meta.keys).to contain_exactly("code", "count")
      expect(meta.values).to contain_exactly("gamma", 5)
      expect(meta.slice("code")).to eq("code" => "gamma")
      expect(meta.except("count")).to eq("code" => "gamma")

      yielded = {}
      meta.each { |k, v| yielded[k] = v }
      expect(yielded).to eq("code" => "gamma", "count" => 5)
    end
  end

  describe ".from_h" do
    it "instantiates from native Hash with string or symbol keys" do
      meta = test_metadata_class.from_h({ code: "delta", count: 10 })
      expect(meta.code).to eq("delta")
      expect(meta.count).to eq(10)
    end

    it "instantiates safely from ActionController::Parameters" do
      params = ActionController::Parameters.new(code: "from_params", count: 4)
      meta = test_metadata_class.from_h(params)
      expect(meta.code).to eq("from_params")
      expect(meta.count).to eq(4)
    end

    it "tracks unrecognized keys" do
      meta = test_metadata_class.from_h({ code: "omega", alien_field: "unknown" })
      expect(meta.code).to eq("omega")
      expect(meta.unrecognized_keys).to eq([ "alien_field" ])
      expect(meta).not_to be_valid
    end
  end

  describe "Type casting" do
    let(:type) { test_metadata_class.to_type }

    it "casts ActionController::Parameters into typed metadata" do
      params = ActionController::Parameters.new(code: "casted_param", count: 7)
      casted = type.cast(params)
      expect(casted).to be_a(test_metadata_class)
      expect(casted.code).to eq("casted_param")
      expect(casted.count).to eq(7)
    end

    it "casts JSON strings into typed metadata" do
      json_str = JSON.generate({ code: "from_json", count: 8 })
      casted = type.cast(json_str)
      expect(casted).to be_a(test_metadata_class)
      expect(casted.code).to eq("from_json")
      expect(casted.count).to eq(8)
    end

    it "casts instances of the target class directly" do
      original = test_metadata_class.new(code: "same", count: 9)
      casted = type.cast(original)
      expect(casted).to be(original)
    end
  end
end
