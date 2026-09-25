# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ai::ToonService do
  describe ".encode" do
    it "encodes primitive values" do
      expect(described_class.encode("hello")).to eq("hello")
      expect(described_class.encode("hello, world")).to eq('"hello, world"')
      expect(described_class.encode(42)).to eq("42")
      expect(described_class.encode(3.14)).to eq("3.14")
      expect(described_class.encode(true)).to eq("true")
      expect(described_class.encode(false)).to eq("false")
      expect(described_class.encode(nil)).to eq("null")
    end

    it "quotes strings that resemble numbers, booleans, or null" do
      expect(described_class.encode("42")).to eq('"42"')
      expect(described_class.encode("true")).to eq('"true"')
      expect(described_class.encode("false")).to eq('"false"')
      expect(described_class.encode("null")).to eq('"null"')
    end

    it "encodes inline primitive arrays" do
      expect(described_class.encode([])).to eq("[0]:")
      expect(described_class.encode([1, 2, 3])).to eq("[3]: 1,2,3")
      expect(described_class.encode(["admin", "user", "guest"])).to eq("[3]: admin,user,guest")
      expect(described_class.encode(["tag,1", "tag:2"])).to eq('[2]: "tag,1","tag:2"')
    end

    it "encodes uniform arrays into tabular form" do
      users = [
        { id: 1, name: "Alice", role: "admin", active: true },
        { id: 2, name: "Bob", role: "member", active: false }
      ]

      expected = <<~TOON.strip
        [2]{id,name,role,active}:
          1,Alice,admin,true
          2,Bob,member,false
      TOON

      expect(described_class.encode(users)).to eq(expected)
    end

    it "encodes key-value objects with 2-space indentation" do
      data = {
        name: "RexOne",
        version: "2.0",
        enabled: true,
        meta: {
          region: "us-east-1",
          replicas: 3
        }
      }

      expected = <<~TOON.strip
        name: RexOne
        version: "2.0"
        enabled: true
        meta:
          region: us-east-1
          replicas: 3
      TOON

      expect(described_class.encode(data)).to eq(expected)
    end

    it "encodes nested tabular arrays under object keys" do
      data = {
        catalog: "Electronics",
        products: [
          { id: "p1", name: "Keyboard", price: 100 },
          { id: "p2", name: "Mouse", price: 50 }
        ]
      }

      expected = <<~TOON.strip
        catalog: Electronics
        products[2]{id,name,price}:
          p1,Keyboard,100
          p2,Mouse,50
      TOON

      expect(described_class.encode(data)).to eq(expected)
    end

    it "encodes keyed tabular objects" do
      data = {
        production: { region: "us-east-1", replicas: 6 },
        staging: { region: "us-west-2", replicas: 2 }
      }

      expected = <<~TOON.strip
        [2:]{region,replicas}:
          production: us-east-1,6
          staging: us-west-2,2
      TOON

      expect(described_class.encode(data)).to eq(expected)
    end

    it "falls back to list form for non-uniform arrays" do
      data = [
        1,
        { name: "Mixed" },
        "raw string"
      ]

      expected = <<~TOON.strip
        [3]:
          - 1
          - name: Mixed
          - raw string
      TOON

      expect(described_class.encode(data)).to eq(expected)
    end
  end

  describe ".decode" do
    it "decodes tabular arrays into an array of hashes" do
      toon = <<~TOON
        [2]{id,name,role,active}:
          1,Alice,admin,true
          2,Bob,member,false
      TOON

      result = described_class.decode(toon)
      expect(result).to eq([
        { "id" => 1, "name" => "Alice", "role" => "admin", "active" => true },
        { "id" => 2, "name" => "Bob", "role" => "member", "active" => false }
      ])
    end

    it "decodes named tabular arrays into a keyed hash" do
      toon = <<~TOON
        users[2]{id,name,active}:
          10,Charlie,true
          20,Dave,false
      TOON

      result = described_class.decode(toon)
      expect(result).to eq({
        "users" => [
          { "id" => 10, "name" => "Charlie", "active" => true },
          { "id" => 20, "name" => "Dave", "active" => false }
        ]
      })
    end

    it "decodes inline primitive arrays" do
      expect(described_class.decode("[3]: 1,2,3")).to eq([1, 2, 3])
      expect(described_class.decode('tags[2]: "tag,1",normal')).to eq({ "tags" => ["tag,1", "normal"] })
      expect(described_class.decode("[0]:")).to eq([])
    end

    it "decodes keyed tabular objects" do
      toon = <<~TOON
        environments[2:]{region,replicas}:
          production: us-east-1,6
          staging: us-west-2,2
      TOON

      result = described_class.decode(toon)
      expect(result).to eq({
        "environments" => {
          "production" => { "region" => "us-east-1", "replicas" => 6 },
          "staging" => { "region" => "us-west-2", "replicas" => 2 }
        }
      })
    end

    it "decodes indented key-value objects" do
      toon = <<~TOON
        name: Alice
        age: 30
        active: true
        meta:
          role: admin
          region: us-east-1
      TOON

      result = described_class.decode(toon)
      expect(result).to eq({
        "name" => "Alice",
        "age" => 30,
        "active" => true,
        "meta" => {
          "role" => "admin",
          "region" => "us-east-1"
        }
      })
    end

    it "ignores comment lines" do
      toon = <<~TOON
        # This is a comment header
        name: RexOne
        # Mid-block comment
        version: "2.0"
      TOON

      result = described_class.decode(toon)
      expect(result).to eq({
        "name" => "RexOne",
        "version" => "2.0"
      })
    end
  end

  describe "Centralized JSON <-> TOON Converters" do
    let(:sample_data) do
      [
        { "id" => 1, "title" => "First Task", "completed" => false, "score" => 85.5 },
        { "id" => 2, "title" => "Second, with comma", "completed" => true, "score" => 92.0 },
        { "id" => 3, "title" => "Third Task", "completed" => false, "score" => 78.0 }
      ]
    end

    it "converts JSON string to TOON string via .json_to_toon" do
      json_input = JSON.generate(sample_data)
      toon_output = described_class.json_to_toon(json_input)

      expect(toon_output).to include("[3]{id,title,completed,score}:")
      expect(toon_output).to include('  2,"Second, with comma",true,92.0')
    end

    it "converts TOON string to JSON string via .toon_to_json" do
      toon_input = described_class.encode(sample_data)
      json_output = described_class.toon_to_json(toon_input)

      parsed = JSON.parse(json_output)
      expect(parsed).to eq(sample_data)
    end

    it "guarantees lossless round-trip consistency across conversions" do
      json_orig = JSON.generate(sample_data)
      converted_toon = described_class.json_to_toon(json_orig)
      restored_json = described_class.toon_to_json(converted_toon)

      expect(JSON.parse(restored_json)).to eq(sample_data)
    end
  end

  describe ".format_prompt_context" do
    it "wraps encoded TOON data inside a labeled context block" do
      users = [
        { id: 1, name: "Alice" },
        { id: 2, name: "Bob" }
      ]

      result = described_class.format_prompt_context("Active Users", users)
      expect(result).to start_with("[Context: Active Users (TOON)]")
      expect(result).to include("[2]{id,name}:")
      expect(result).to include("  1,Alice")
    end
  end

  describe ".output_instruction" do
    it "generates a clean prompt instruction for models" do
      instruction = described_class.output_instruction(fields: [:id, :title, :priority], array_name: "tasks")
      expect(instruction).to eq("Output the result strictly in Token-Oriented Object Notation (TOON) format using: tasks[N]{id,title,priority}:")
    end
  end

  describe ".token_savings" do
    it "calculates token metrics and demonstrates significant token savings on tabular arrays" do
      dataset = 20.times.map do |i|
        {
          id: i + 1,
          email: "user#{i}@example.com",
          first_name: "User#{i}",
          last_name: "Test#{i}",
          status: "active",
          role: "member"
        }
      end

      metrics = described_class.token_savings(dataset)
      expect(metrics[:json_tokens]).to be > metrics[:toon_tokens]
      expect(metrics[:saved_tokens]).to be > 0
      expect(metrics[:percent_saved]).to be >= 35.0

      Rails.logger.info("TOON Savings Benchmark: #{metrics[:percent_saved]}% saved (#{metrics[:saved_tokens]} tokens saved)")
    end
  end
end
