# frozen_string_literal: true

# app/services/chat/text_service.rb
module Chat
  class TextService
    DEFAULT_MAX_CHARS = AiConstants::Defaults::MESSAGE_MAX_CHARS

    class << self
      # Split text into sequential chunks within max_chars respecting natural boundaries
      # (paragraphs -> linebreaks -> sentences -> words -> hard cuts).
      def chunk(text, max_chars: DEFAULT_MAX_CHARS)
        return [] if text.blank?

        text = text.to_s.strip
        return [ text ] if text.length <= max_chars

        chunks = []
        remaining = text

        while remaining.length > max_chars
          split_point = find_split_point(remaining, max_chars, "\n\n")
          split_point ||= find_split_point(remaining, max_chars, "\n")
          split_point ||= find_sentence_split_point(remaining, max_chars)
          split_point ||= find_split_point(remaining, max_chars, " ")
          split_point ||= max_chars

          chunk_part = remaining[0...split_point].strip
          chunks << chunk_part unless chunk_part.empty?

          remaining = remaining[split_point..].to_s.strip
        end

        chunks << remaining unless remaining.empty?
        chunks
      end

      # Stitch multi-part chunks sharing the same split_id into a single unified text string
      def stitch(messages)
        messages.map(&:content).join("\n\n")
      end

      private

      def find_split_point(text, max_chars, delimiter)
        sub = text[0...max_chars]
        idx = sub.rindex(delimiter)
        return nil unless idx && idx > 0

        idx + delimiter.length
      end

      def find_sentence_split_point(text, max_chars)
        sub = text[0...max_chars]
        matches = sub.to_enum(:scan, /[.!?]\s/).map { Regexp.last_match.end(0) }
        matches.last if matches.present? && matches.last.positive?
      end
    end
  end
end
