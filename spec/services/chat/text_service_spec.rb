# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::TextService do
  describe ".chunk" do
    it "returns an empty array when text is blank" do
      expect(described_class.chunk("")).to eq([])
      expect(described_class.chunk(nil)).to eq([])
      expect(described_class.chunk("   ")).to eq([])
    end

    it "returns a single chunk when text length is within max_chars" do
      text = "Short message under limit."
      expect(described_class.chunk(text, max_chars: 100)).to eq([text])
    end

    it "splits on double newline paragraph boundaries" do
      p1 = "First paragraph content."
      p2 = "Second paragraph content."
      text = "#{p1}\n\n#{p2}"

      chunks = described_class.chunk(text, max_chars: 30)
      expect(chunks).to eq([p1, p2])
    end

    it "splits on single newline when paragraph is too long" do
      l1 = "Line one of text."
      l2 = "Line two of text."
      text = "#{l1}\n#{l2}"

      chunks = described_class.chunk(text, max_chars: 20)
      expect(chunks).to eq([l1, l2])
    end

    it "splits on sentence boundaries when line is too long" do
      s1 = "First sentence here."
      s2 = "Second sentence here."
      text = "#{s1} #{s2}"

      chunks = described_class.chunk(text, max_chars: 25)
      expect(chunks).to eq([s1, s2])
    end

    it "splits on spaces when sentence is too long" do
      text = "Word1 Word2 Word3 Word4"
      chunks = described_class.chunk(text, max_chars: 12)
      expect(chunks).to eq(["Word1 Word2", "Word3 Word4"])
    end

    it "falls back to hard cut when a word exceeds max_chars" do
      text = "a" * 25
      chunks = described_class.chunk(text, max_chars: 10)
      expect(chunks).to eq(["a" * 10, "a" * 10, "a" * 5])
    end
  end

  describe ".stitch" do
    it "joins message content with double newlines" do
      m1 = instance_double("Chat::Message", content: "Part 1")
      m2 = instance_double("Chat::Message", content: "Part 2")
      expect(described_class.stitch([m1, m2])).to eq("Part 1\n\nPart 2")
    end
  end
end
