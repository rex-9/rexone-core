# frozen_string_literal: true

require "rails_helper"

RSpec.describe TimeService, type: :service do
  describe ".current" do
    it "returns the current time in UTC" do
      expect(described_class.current).to be_a(ActiveSupport::TimeWithZone)
      expect(described_class.current.time_zone.name).to eq("UTC")
    end
  end

  describe ".to_epoch" do
    it "returns nil for blank values" do
      expect(described_class.to_epoch(nil)).to be_nil
      expect(described_class.to_epoch("")).to be_nil
      expect(described_class.to_epoch("   ")).to be_nil
    end

    it "converts Numeric values to integer seconds" do
      expect(described_class.to_epoch(1_790_800_000)).to eq(1_790_800_000)
      expect(described_class.to_epoch(1_790_800_000.5)).to eq(1_790_800_000)
    end

    it "converts numeric string epochs to integer seconds" do
      expect(described_class.to_epoch("1790800000")).to eq(1_790_800_000)
      expect(described_class.to_epoch(" 1790800000 ")).to eq(1_790_800_000)
    end

    it "converts Time and ActiveSupport::TimeWithZone objects to integer seconds" do
      time = Time.zone.parse("2026-10-01 12:00:00 UTC")
      expect(described_class.to_epoch(time)).to eq(time.to_i)
    end

    it "converts Date objects to integer seconds at UTC midnight" do
      date = Date.new(2026, 10, 1)
      expect(described_class.to_epoch(date)).to eq(date.to_time.utc.to_i)
    end

    it "converts ISO 8601 strings to Unix timestamp integer seconds" do
      expected_epoch = Time.zone.parse("2026-10-01T15:30:00Z").to_i
      expect(described_class.to_epoch("2026-10-01T15:30:00Z")).to eq(expected_epoch)
      expect(described_class.to_epoch("2026-10-01T15:30:00.000Z")).to eq(expected_epoch)
    end

    it "returns nil for unparseable strings or unsupported objects" do
      expect(described_class.to_epoch("invalid-date-string")).to be_nil
      expect(described_class.to_epoch(Object.new)).to be_nil
    end
  end

  describe ".parse_utc" do
    it "returns fallback when input is blank" do
      fallback = Time.zone.parse("2026-01-01 00:00:00 UTC")
      expect(described_class.parse_utc(nil)).to be_nil
      expect(described_class.parse_utc("", fallback: fallback)).to eq(fallback)
    end

    it "parses Numeric timestamps into UTC TimeWithZone" do
      epoch = 1_790_800_000
      parsed = described_class.parse_utc(epoch)
      expect(parsed).to be_a(ActiveSupport::TimeWithZone)
      expect(parsed.to_i).to eq(epoch)
      expect(parsed.time_zone.name).to eq("UTC")
    end

    it "parses numeric string epochs into UTC TimeWithZone" do
      epoch = 1_790_800_000
      parsed = described_class.parse_utc(epoch.to_s)
      expect(parsed).to be_a(ActiveSupport::TimeWithZone)
      expect(parsed.to_i).to eq(epoch)
      expect(parsed.time_zone.name).to eq("UTC")
    end

    it "parses ISO 8601 strings into UTC TimeWithZone" do
      parsed = described_class.parse_utc("2026-10-01T15:30:00Z")
      expect(parsed).to be_a(ActiveSupport::TimeWithZone)
      expect(parsed.time_zone.name).to eq("UTC")
      expect(parsed.iso8601).to eq("2026-10-01T15:30:00Z")
    end

    it "converts non-UTC strings to UTC" do
      # +07:00 at 17:00 is 10:00 UTC
      parsed = described_class.parse_utc("2026-10-01T17:00:00+07:00")
      expect(parsed.time_zone.name).to eq("UTC")
      expect(parsed.hour).to eq(10)
    end

    it "returns fallback when string is unparseable" do
      fallback = Time.zone.parse("2026-01-01 00:00:00 UTC")
      expect(described_class.parse_utc("not-a-valid-date", fallback: fallback)).to eq(fallback)
      expect(described_class.parse_utc("not-a-valid-date")).to be_nil
    end
  end

  describe ".iso8601" do
    it "returns nil for blank values" do
      expect(described_class.iso8601(nil)).to be_nil
      expect(described_class.iso8601("")).to be_nil
    end

    it "returns formatted UTC ISO 8601 string for timestamps and time objects" do
      time = Time.zone.parse("2026-10-01 12:00:00 UTC")
      expect(described_class.iso8601(time)).to eq("2026-10-01T12:00:00Z")
      expect(described_class.iso8601(time.to_i)).to eq("2026-10-01T12:00:00Z")
      expect(described_class.iso8601("2026-10-01T12:00:00Z")).to eq("2026-10-01T12:00:00Z")
    end

    it "returns nil for invalid values" do
      expect(described_class.iso8601("invalid")).to be_nil
    end
  end
end
