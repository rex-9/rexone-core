# frozen_string_literal: true

# app/services/ai/toon_service.rb
# Token-Oriented Object Notation (TOON) Encoder & Decoder Service
# Optimized serialization format for Large Language Model (LLM) prompts and completions.
# Achieves 30-60% token reduction over JSON with lossless round-tripping.
# Specification: https://github.com/toon-format/spec
require "json"
require "strscan"
require "csv"

module Ai
  class ToonService
    Error = Class.new(StandardError)

    DEFAULT_DELIMITER = ","
    INDENT = "  "
    TOON_SYSTEM_INSTRUCTION = "Output all structured data, key-value mappings, and tabular records strictly in Token-Oriented Object Notation (TOON) format inside ```toon code blocks. Never output raw JSON.".freeze

    class << self
      # Encodes a Ruby object (Hash, Array, primitive) into a TOON formatted string.
      def encode(data, delimiter: DEFAULT_DELIMITER)
        case data
        when Array
          encode_array(nil, data, delimiter: delimiter, indent_level: 0)
        when Hash
          encode_hash(data, delimiter: delimiter, indent_level: 0)
        else
          encode_primitive(data, delimiter: delimiter)
        end
      end

      # Decodes a TOON formatted string into native Ruby data structures (Hash, Array, primitive).
      def decode(text, delimiter: DEFAULT_DELIMITER)
        return nil if text.nil?

        clean_text = text.to_s.lines.map do |line|
          stripped = line.rstrip
          stripped.start_with?("#") ? nil : stripped
        end.compact.join("\n").strip

        return nil if clean_text.empty?

        lines = clean_text.lines.map(&:rstrip)
        parse_block(lines, delimiter: delimiter)
      end

      # Centralized converter: JSON (Hash, Array, IO, or String) -> TOON string.
      def json_to_toon(data_or_text, delimiter: DEFAULT_DELIMITER)
        return data_or_text if data_or_text.blank?
        return encode(data_or_text, delimiter: delimiter) if data_or_text.is_a?(Hash) || data_or_text.is_a?(Array)

        raw = data_or_text.respond_to?(:read) ? data_or_text.read : data_or_text.to_s
        trimmed = raw.strip

        # 1. Bare JSON: whole text is a JSON object or array
        if looks_like_bare_json?(trimmed)
          begin
            parsed = JSON.parse(trimmed)
            return encode(parsed, delimiter: delimiter) if parsed.is_a?(Hash) || parsed.is_a?(Array)
          rescue JSON::ParserError
            # Fall through to fenced/embedded
          end
        end

        # 2. Markdown fenced blocks ```json ... ``` or ``` ... ``` with JSON content
        processed = replace_fenced_json(raw, delimiter: delimiter)

        # 3. Embedded JSON objects or arrays in conversational prose
        replace_embedded_json(processed, delimiter: delimiter)
      end

      # Centralized converter: TOON (String, Hash, or Array) -> JSON string.
      def toon_to_json(data_or_text, pretty: true, delimiter: DEFAULT_DELIMITER)
        return data_or_text if data_or_text.blank?
        if data_or_text.is_a?(Hash) || data_or_text.is_a?(Array)
          return pretty ? JSON.pretty_generate(data_or_text) : JSON.generate(data_or_text)
        end
        return data_or_text unless data_or_text.is_a?(String)

        # 1. Markdown fenced blocks ```toon ... ```
        processed = replace_fenced_toon(data_or_text, pretty: pretty, delimiter: delimiter)

        # 2. Bare TOON data (whole text is a TOON table, keyed table, array, or key-value map)
        trimmed = processed.strip
        if looks_like_bare_toon?(trimmed)
          begin
            decoded = decode(trimmed, delimiter: delimiter)
            if (decoded.is_a?(Hash) && decoded.any?) || (decoded.is_a?(Array) && decoded.any?)
              return pretty ? JSON.pretty_generate(decoded) : JSON.generate(decoded)
            end
          rescue StandardError
            # Fall through to embedded
          end
        end

        # 3. Embedded bare TOON tabular blocks inside conversational text
        replace_embedded_toon_tables(processed, pretty: pretty, delimiter: delimiter)
      end

      # Calculates character and token savings comparing standard JSON against TOON.
      def token_savings(data_or_json)
        json_str = data_or_json.is_a?(String) ? data_or_json : JSON.generate(data_or_json)
        toon_str = data_or_json.is_a?(String) ? json_to_toon(data_or_json) : encode(data_or_json)

        # Standard industry heuristic (~3.8 to 4 chars per token)
        json_tokens = (json_str.length / 3.8).ceil
        toon_tokens = (toon_str.length / 3.8).ceil
        saved = [ json_tokens - toon_tokens, 0 ].max
        pct = json_tokens.positive? ? ((saved.to_f / json_tokens) * 100).round(1) : 0.0

        {
          json_chars: json_str.length,
          toon_chars: toon_str.length,
          json_tokens: json_tokens,
          toon_tokens: toon_tokens,
          saved_tokens: saved,
          percent_saved: pct
        }
      end

      # Checks whether a text string contains structured JSON (fenced, bare, or embedded).
      def json_in_text?(text)
        return false if text.blank?
        return true if text.is_a?(Hash) || text.is_a?(Array)
        return false unless text.is_a?(String)

        # Fenced markdown code block
        return true if text =~ /```(?:json)?\s*\n\s*[\{\[]/m

        # Bare JSON
        trimmed = text.strip
        if (trimmed.start_with?("{") && trimmed.end_with?("}")) || (trimmed.start_with?("[") && trimmed.end_with?("]"))
          begin
            parsed = JSON.parse(trimmed)
            return true if parsed.is_a?(Hash) || parsed.is_a?(Array)
          rescue JSON::ParserError
            # Not bare JSON
          end
        end

        # Embedded JSON object or array
        has_embedded_json?(text)
      end

      # Checks whether a text string contains TOON structured data (fenced, bare, or embedded tabular).
      def toon_in_text?(text)
        return false if text.blank?
        return false unless text.is_a?(String)

        return true if text =~ /```toon\s*\n/
        return true if looks_like_bare_toon?(text)
        return true if text =~ /(?:^|\n)([a-zA-Z0-9_.-]*\[\d+:?\]\{[^}]+\}:(?:\n\s{2,}.*)+)/

        false
      end

      # Prepares conversation messages for LLM dispatch:
      # - Converts all JSON payloads to TOON format across all message roles.
      # - When JSON was converted or instruction enforced, injects TOON system directive.
      def prepare_messages_for_llm(messages, enforce_instruction: nil, delimiter: DEFAULT_DELIMITER)
        return [] if messages.nil?

        converted_any_json = false
        prepared = messages.map do |msg|
          role = (msg[:role] || msg["role"]).to_s
          content = msg[:content] || msg["content"]

          if json_in_text?(content)
            converted_any_json = true
            converted_content = json_to_toon(content, delimiter: delimiter)
            { role: role, content: converted_content }
          else
            { role: role, content: content }
          end
        end

        should_enforce = enforce_instruction.nil? ? converted_any_json : enforce_instruction
        if should_enforce
          system_idx = prepared.find_index { |m| m[:role] == AiConstants::ChatRole::SYSTEM }
          if system_idx
            sys_msg = prepared[system_idx]
            sys_content = sys_msg[:content].to_s
            unless sys_content.include?(TOON_SYSTEM_INSTRUCTION)
              prepared[system_idx] = {
                role: AiConstants::ChatRole::SYSTEM,
                content: sys_content.present? ? "#{sys_content}\n\n#{TOON_SYSTEM_INSTRUCTION}" : TOON_SYSTEM_INSTRUCTION
              }
            end
          else
            prepared.unshift({ role: AiConstants::ChatRole::SYSTEM, content: TOON_SYSTEM_INSTRUCTION })
          end
        end

        prepared
      end

      private

      # === UNIVERSAL BIDIRECTIONAL PIPELINE HELPERS ===

      def replace_fenced_json(text, delimiter: DEFAULT_DELIMITER)
        text.gsub(/```([a-zA-Z0-9_-]*)\s*\n(.*?)\n```/m) do |match|
          lang = $1.to_s.downcase.strip
          body = $2
          if lang == "json" || (lang.empty? && (body.strip.start_with?("{") || body.strip.start_with?("[")))
            begin
              parsed = JSON.parse(body.strip)
              if parsed.is_a?(Hash) || parsed.is_a?(Array)
                "```toon\n#{encode(parsed, delimiter: delimiter)}\n```"
              else
                match
              end
            rescue JSON::ParserError
              match
            end
          else
            match
          end
        end
      end

      def replace_embedded_json(text, delimiter: DEFAULT_DELIMITER)
        return text unless text.include?("{") || text.include?("[")

        result = String.new
        scanner = StringScanner.new(text)

        until scanner.eos?
          chunk = scanner.scan(/[^\{\[]+/)
          result << chunk if chunk
          break if scanner.eos?

          char = scanner.peek(1)
          if char == "{" || char == "["
            start_pos = scanner.pos
            candidate = extract_balanced_bracket(scanner.string, start_pos)
            if candidate
              parsed = nil
              begin
                if candidate.length >= 4 && (candidate.include?(":") || candidate.include?(","))
                  parsed = JSON.parse(candidate)
                end
              rescue JSON::ParserError
                parsed = nil
              end

              if parsed.is_a?(Hash) && parsed.any?
                toon = encode(parsed, delimiter: delimiter)
                result << "\n```toon\n#{toon}\n```\n"
                scanner.pos = start_pos + candidate.length
                next
              elsif parsed.is_a?(Array) && parsed.any? && (parsed.first.is_a?(Hash) || parsed.size > 1)
                toon = encode(parsed, delimiter: delimiter)
                result << "\n```toon\n#{toon}\n```\n"
                scanner.pos = start_pos + candidate.length
                next
              end
            end

            result << scanner.getch
          end
        end

        result
      end

      def has_embedded_json?(text)
        return false unless text.include?("{") || text.include?("[")

        scanner = StringScanner.new(text)
        until scanner.eos?
          scanner.scan(/[^\{\[]+/)
          break if scanner.eos?

          char = scanner.peek(1)
          if char == "{" || char == "["
            start_pos = scanner.pos
            candidate = extract_balanced_bracket(scanner.string, start_pos)
            if candidate && candidate.length >= 4 && (candidate.include?(":") || candidate.include?(","))
              begin
                parsed = JSON.parse(candidate)
                return true if parsed.is_a?(Hash) && parsed.any?
                return true if parsed.is_a?(Array) && parsed.any? && (parsed.first.is_a?(Hash) || parsed.size > 1)
              rescue JSON::ParserError
                # Continue scanning
              end
            end
            scanner.getch
          end
        end

        false
      end

      def extract_balanced_bracket(str, start_pos)
        open_char = str[start_pos]
        close_char = open_char == "{" ? "}" : "]"
        depth = 0
        in_string = false
        escaped = false

        (start_pos...str.length).each do |i|
          c = str[i]

          if in_string
            if escaped
              escaped = false
            elsif c == "\\"
              escaped = true
            elsif c == '"'
              in_string = false
            end
            next
          end

          if c == '"'
            in_string = true
          elsif c == open_char
            depth += 1
          elsif c == close_char
            depth -= 1
            return str[start_pos..i] if depth.zero?
          end
        end

        nil
      end

      def looks_like_bare_json?(text)
        (text.start_with?("{") && text.end_with?("}")) || (text.start_with?("[") && text.end_with?("]"))
      end

      def looks_like_bare_toon?(text)
        return false if text.blank?
        lines = text.strip.lines.map(&:rstrip).reject(&:empty?)
        return false if lines.empty?

        first_line = lines.first.strip

        # 1. Tabular Array header: [N]{field1,field2,...}: or name[N]{field1,field2,...}:
        return true if first_line =~ /\A([a-zA-Z0-9_.-]+)?\[\d+\]\{[^}]+\}:\z/

        # 2. Keyed Tabular header: [N:]{field1,field2,...}: or name[N:]{field1,field2,...}:
        return true if first_line =~ /\A([a-zA-Z0-9_.-]+)?\[\d+:\]\{[^}]+\}:\z/

        # 3. Inline Primitive Array: [N]: v1,v2 or name[N]: v1,v2
        return true if first_line =~ /\A([a-zA-Z0-9_.-]+)?\[\d+\]:\s*.+\z/

        # 4. Single-line primitive key-value check (avoid English sentence matching like "Note: ...")
        if lines.size == 1
          return true if first_line =~ /\A[a-zA-Z0-9_.-]+:\s*(true|false|null|-?\d+(\.\d+)?|\[\]|\{\})\z/
          return false
        end

        # 5. Multi-line Key-Value Map
        key_count = 0
        all_match = lines.all? do |line|
          stripped = line.strip
          next true if stripped.start_with?("#")

          if line =~ /\A([a-zA-Z0-9_.-]+):\s*(.*)\z/ ||
             line =~ /\A([a-zA-Z0-9_.-]+)\[\d+:?\]\{[^}]+\}:\z/ ||
             line =~ /\A([a-zA-Z0-9_.-]+)\[\d+\]:\s*.*\z/
            key_count += 1
            true
          elsif line =~ /\A\s{2,}/
            true
          else
            false
          end
        end

        key_count >= 2 && all_match
      end

      def replace_fenced_toon(text, pretty: true, delimiter: DEFAULT_DELIMITER)
        text.gsub(/```toon\s*\n(.*?)\n```/m) do |match|
          body = $1
          begin
            decoded = decode(body.strip, delimiter: delimiter)
            if decoded.is_a?(Hash) || decoded.is_a?(Array)
              json_body = pretty ? JSON.pretty_generate(decoded) : JSON.generate(decoded)
              "```json\n#{json_body}\n```"
            else
              match
            end
          rescue StandardError
            match
          end
        end
      end

      def replace_embedded_toon_tables(text, pretty: true, delimiter: DEFAULT_DELIMITER)
        text.gsub(/(?:^|\n)([a-zA-Z0-9_.-]*\[\d+:?\]\{[^}]+\}:(?:\n\s{2,}.*)+)/) do |match|
          block = match.strip
          begin
            decoded = decode(block, delimiter: delimiter)
            if decoded.is_a?(Hash) || decoded.is_a?(Array)
              json_body = pretty ? JSON.pretty_generate(decoded) : JSON.generate(decoded)
              "\n```json\n#{json_body}\n```\n"
            else
              match
            end
          rescue StandardError
            match
          end
        end
      end

      # === ENCODING HELPERS ===

      def encode_primitive(val, delimiter: DEFAULT_DELIMITER)
        case val
        when nil then "null"
        when true then "true"
        when false then "false"
        when Integer, Float then val.to_s
        when Symbol then encode_primitive(val.to_s, delimiter: delimiter)
        when String
          if string_requires_quoting?(val, delimiter)
            JSON.generate(val)
          else
            val
          end
        else
          JSON.generate(val.to_s)
        end
      end

      def string_requires_quoting?(val, delimiter)
        return true if val.empty?
        return true if val.include?(delimiter) || val.include?(":") || val.include?('"') || val.include?("\n")
        return true if val.start_with?(" ") || val.end_with?(" ")
        return true if val.start_with?("-") || val.start_with?("[") || val.start_with?("{") || val.start_with?("#")
        return true if val =~ /\A-?\d+(\.\d+)?\z/
        return true if %w[true false null].include?(val)

        false
      end

      def encode_hash(hash, delimiter: DEFAULT_DELIMITER, indent_level: 0)
        return "{}" if hash.empty?

        prefix = INDENT * indent_level

        # Check for Keyed Tabular object: Hash where all values are non-empty uniform Hashes
        if keyed_tabular_eligible?(hash)
          first_keys = hash.values.first.keys
          header = "#{prefix}[#{hash.size}:]{#{first_keys.map(&:to_s).join(',')}}:"
          rows = hash.map do |k, v|
            row_prefix = INDENT * (indent_level + 1)
            row_vals = first_keys.map { |fk| encode_primitive(fetch_field(v, fk), delimiter: delimiter) }
            "#{row_prefix}#{encode_primitive(k.to_s, delimiter: delimiter)}: #{row_vals.join(delimiter)}"
          end
          return ([ header ] + rows).join("\n")
        end

        lines = []
        hash.each do |k, v|
          key_str = encode_primitive(k.to_s, delimiter: delimiter)
          case v
          when Hash
            if v.empty?
              lines << "#{prefix}#{key_str}: {}"
            elsif keyed_tabular_eligible?(v)
              first_keys = v.values.first.keys
              lines << "#{prefix}#{key_str}[#{v.size}:]{#{first_keys.map(&:to_s).join(',')}}:"
              v.each do |sub_k, sub_v|
                row_prefix = INDENT * (indent_level + 1)
                row_vals = first_keys.map { |fk| encode_primitive(fetch_field(sub_v, fk), delimiter: delimiter) }
                lines << "#{row_prefix}#{encode_primitive(sub_k.to_s, delimiter: delimiter)}: #{row_vals.join(delimiter)}"
              end
            else
              lines << "#{prefix}#{key_str}:"
              lines << encode_hash(v, delimiter: delimiter, indent_level: indent_level + 1)
            end
          when Array
            lines << encode_array(key_str, v, delimiter: delimiter, indent_level: indent_level)
          else
            lines << "#{prefix}#{key_str}: #{encode_primitive(v, delimiter: delimiter)}"
          end
        end

        lines.join("\n")
      end

      def encode_array(key_prefix, array, delimiter: DEFAULT_DELIMITER, indent_level: 0)
        prefix = INDENT * indent_level
        name_tag = key_prefix ? "#{prefix}#{key_prefix}" : prefix

        if array.empty?
          return "#{name_tag}[0]:"
        end

        # 1. Inline Primitive Array Form: [N]: v1,v2,v3
        if array.all? { |item| primitive?(item) }
          vals = array.map { |item| encode_primitive(item, delimiter: delimiter) }.join(delimiter)
          return "#{name_tag}[#{array.size}]: #{vals}"
        end

        # 2. Tabular Array Form: [N]{field1,field2,...}:
        if tabular_eligible?(array)
          fields = array.first.keys
          header = "#{name_tag}[#{array.size}]{#{fields.map(&:to_s).join(',')}}:"
          rows = array.map do |item|
            row_prefix = INDENT * (indent_level + 1)
            row_vals = fields.map { |f| encode_primitive(fetch_field(item, f), delimiter: delimiter) }
            "#{row_prefix}#{row_vals.join(delimiter)}"
          end
          return ([ header ] + rows).join("\n")
        end

        # 3. List Form Fallback: [N]: with - items
        header = "#{name_tag}[#{array.size}]:"
        rows = array.map do |item|
          row_prefix = INDENT * (indent_level + 1)
          if primitive?(item)
            "#{row_prefix}- #{encode_primitive(item, delimiter: delimiter)}"
          elsif item.is_a?(Hash)
            item_lines = encode_hash(item, delimiter: delimiter, indent_level: indent_level + 2)
            first_line, *rest = item_lines.lines.map(&:rstrip)
            first_stripped = first_line.sub(/\A\s*/, "")
            ([ "#{row_prefix}- #{first_stripped}" ] + rest).join("\n")
          else
            "#{row_prefix}- #{encode_primitive(item.to_s, delimiter: delimiter)}"
          end
        end
        ([ header ] + rows).join("\n")
      end

      def primitive?(val)
        val.nil? || val.is_a?(TrueClass) || val.is_a?(FalseClass) || val.is_a?(Numeric) || val.is_a?(String) || val.is_a?(Symbol)
      end

      def tabular_eligible?(array)
        return false unless array.is_a?(Array) && array.size.positive?
        return false unless array.all? { |item| item.is_a?(Hash) && item.size.positive? }

        first_keys = array.first.keys.map(&:to_s).sort
        array.all? do |item|
          item.keys.map(&:to_s).sort == first_keys &&
            item.values.all? { |v| primitive?(v) }
        end
      end

      def keyed_tabular_eligible?(hash)
        return false unless hash.is_a?(Hash) && hash.size.positive?
        return false unless hash.values.all? { |item| item.is_a?(Hash) && item.size.positive? }

        first_keys = hash.values.first.keys.map(&:to_s).sort
        hash.values.all? do |item|
          item.keys.map(&:to_s).sort == first_keys &&
            item.values.all? { |v| primitive?(v) }
        end
      end

      def fetch_field(hash, key)
        if hash.key?(key)
          hash[key]
        elsif hash.key?(key.to_s)
          hash[key.to_s]
        elsif key.respond_to?(:to_sym) && hash.key?(key.to_sym)
          hash[key.to_sym]
        end
      end

      # === DECODING HELPERS ===

      def parse_block(lines, delimiter: DEFAULT_DELIMITER)
        return nil if lines.empty?

        first_line = lines.first.strip

        # 1. Tabular Array: [N]{fields}: or name[N]{fields}:
        if first_line =~ /\A([a-zA-Z0-9_.-]+)?\[(\d+)\]\{([^}]+)\}:\z/
          name = $1
          fields = $3.split(",").map(&:strip)
          rows = lines[1..].map do |line|
            stripped = line.strip
            next if stripped.empty?
            tokens = parse_row_tokens(stripped, delimiter: delimiter)
            fields.zip(tokens).to_h
          end.compact

          return (name && !name.empty?) ? { name => rows } : rows
        end

        # 2. Keyed Tabular Object: [N:]{fields}: or name[N:]{fields}:
        if first_line =~ /\A([a-zA-Z0-9_.-]+)?\[(\d+):\]\{([^}]+)\}:\z/
          name = $1
          fields = $3.split(",").map(&:strip)
          result = {}
          lines[1..].each do |line|
            stripped = line.strip
            next if stripped.empty?
            key, rest = stripped.split(":", 2)
            next unless key && rest
            row_key = decode_primitive_token(key.strip)
            tokens = parse_row_tokens(rest.strip, delimiter: delimiter)
            result[row_key] = fields.zip(tokens).to_h
          end
          return (name && !name.empty?) ? { name => result } : result
        end

        # 3. Inline Primitive Array: [N]: v1,v2 or name[N]: v1,v2
        if first_line =~ /\A([a-zA-Z0-9_.-]+)?\[(\d+)\]:\s*(.*)\z/
          name = $1
          content = $3.strip
          if lines.size == 1 && (!content.empty? || $2.to_i.zero?)
            tokens = content.empty? ? [] : parse_row_tokens(content, delimiter: delimiter)
            return (name && !name.empty?) ? { name => tokens } : tokens
          elsif lines.size > 1 && content.empty?
            # List form with - items
            items = []
            lines[1..].each do |line|
              stripped = line.strip
              if stripped =~ /\A-\s*(.*)\z/
                items << decode_primitive_token($1)
              end
            end
            return (name && !name.empty?) ? { name => items } : items
          end
        end

        # 4. Key-Value Object / Nested Map
        parse_indented_map(lines, delimiter: delimiter)
      end

      def parse_indented_map(lines, delimiter: DEFAULT_DELIMITER)
        result = {}
        i = 0
        while i < lines.size
          line = lines[i]
          stripped = line.strip
          if stripped.empty?
            i += 1
            next
          end

          # Nested Tabular Array under key: key[N]{fields}:
          if stripped =~ /\A([a-zA-Z0-9_.-]+)\[(\d+)\]\{([^}]+)\}:\z/
            key = $1
            fields = $3.split(",").map(&:strip)
            sub_lines = []
            i += 1
            while i < lines.size && lines[i].start_with?("  ")
              sub_lines << lines[i].strip unless lines[i].strip.empty?
              i += 1
            end
            rows = sub_lines.map do |sl|
              tokens = parse_row_tokens(sl, delimiter: delimiter)
              fields.zip(tokens).to_h
            end
            result[key] = rows
            next
          end

          # Nested Keyed Tabular under key: key[N:]{fields}:
          if stripped =~ /\A([a-zA-Z0-9_.-]+)\[(\d+):\]\{([^}]+)\}:\z/
            key = $1
            fields = $3.split(",").map(&:strip)
            sub_map = {}
            i += 1
            while i < lines.size && lines[i].start_with?("  ")
              sl = lines[i].strip
              unless sl.empty?
                sub_k, sub_rest = sl.split(":", 2)
                if sub_k && sub_rest
                  row_tokens = parse_row_tokens(sub_rest.strip, delimiter: delimiter)
                  sub_map[decode_primitive_token(sub_k.strip)] = fields.zip(row_tokens).to_h
                end
              end
              i += 1
            end
            result[key] = sub_map
            next
          end

          # Inline primitive array under key: key[N]: v1,v2
          if stripped =~ /\A([a-zA-Z0-9_.-]+)\[(\d+)\]:\s*(.*)\z/
            key = $1
            count = $2.to_i
            content = $3.strip
            if content.present? || count.zero?
              tokens = content.empty? ? [] : parse_row_tokens(content, delimiter: delimiter)
              result[key] = tokens
              i += 1
              next
            else
              # List form under key
              items = []
              i += 1
              while i < lines.size && lines[i].start_with?("  ")
                item_str = lines[i].strip
                if item_str =~ /\A-\s*(.*)\z/
                  items << decode_primitive_token($1)
                end
                i += 1
              end
              result[key] = items
              next
            end
          end

          # Standard key: value or nested hash
          if stripped =~ /\A([a-zA-Z0-9_.-]+):\s*(.*)\z/
            key = $1
            val_str = $2.strip
            if val_str.empty?
              # Collect indented block
              sub_lines = []
              i += 1
              while i < lines.size && lines[i].start_with?("  ")
                sub_lines << lines[i].sub(/\A  /, "")
                i += 1
              end
              result[key] = parse_block(sub_lines, delimiter: delimiter)
              next
            elsif val_str == "{}"
              result[key] = {}
              i += 1
              next
            else
              result[key] = decode_primitive_token(val_str)
              i += 1
              next
            end
          end

          i += 1
        end

        result.empty? && lines.size == 1 ? decode_primitive_token(lines.first.strip) : result
      end

      def parse_row_tokens(row_string, delimiter: DEFAULT_DELIMITER)
        # Parse comma-separated values respecting quotes
        tokens = []
        scanner = StringScanner.new(row_string)

        until scanner.eos?
          scanner.skip(/\s*/)
          if scanner.scan(/"/)
            # Quoted string
            val = String.new
            until scanner.eos?
              if scanner.scan(/\\"/)
                val << '"'
              elsif scanner.scan(/\\\\/)
                val << "\\"
              elsif scanner.scan(/"/)
                break
              elsif scanner.scan(/[^"\\]+/)
                val << scanner.matched
              else
                break
              end
            end
            tokens << val
            scanner.skip(/\s*/)
            scanner.scan(/#{Regexp.escape(delimiter)}/)
          else
            # Unquoted token
            token = scanner.scan(/[^#{Regexp.escape(delimiter)}]+/)
            tokens << decode_primitive_token(token&.strip)
            scanner.scan(/#{Regexp.escape(delimiter)}/)
          end
        end

        tokens
      end

      def decode_primitive_token(token)
        return nil if token.nil?
        str = token.to_s.strip

        if str.start_with?('"') && str.end_with?('"') && str.length >= 2
          return JSON.parse(str) rescue str[1..-2]
        end

        return nil if str == "null"
        return true if str == "true"
        return false if str == "false"
        return str.to_i if str =~ /\A-?\d+\z/
        return str.to_f if str =~ /\A-?\d+\.\d+\z/

        str
      end
    end
  end
end
