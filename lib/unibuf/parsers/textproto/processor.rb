# frozen_string_literal: true

module Unibuf
  module Parsers
    module Textproto
      # Processor to transform Parslet AST to Ruby hashes
      # Follows fontist pattern - manual transformation, not Parslet::Transform
      class Processor
        class << self
          # Process the AST from the grammar into a normalized hash
          # @param ast [Hash, Array] The Parslet AST
          # @return [Hash] Normalized hash suitable for model construction
          def process(ast)
            return { "fields" => [] } if ast.nil? || ast.empty?

            fields = normalize_fields(ast)
            { "fields" => fields }
          end

          private

          # Normalize fields from AST
          def normalize_fields(ast)
            return [] unless ast

            fields_array = Array(ast)
            normalized = []

            fields_array.each do |item|
              # Handle Parslet::Slice by converting to string first
              next unless item.respond_to?(:key?) || item.respond_to?(:[])

              # New grammar wraps everything in :field
              if item.respond_to?(:[]) && item[:field]
                field_data = item[:field]
                normalized << process_field(field_data)
              end
            end

            normalized
          end

          # Process a single field
          def process_field(field_data)
            name = extract_name(field_data[:field_name])
            value = process_value(field_data[:field_value])

            { "name" => name, "value" => value }
          end

          # Extract field name
          def extract_name(name_data)
            return name_data.to_s unless name_data.respond_to?(:[])

            if name_data[:identifier]
              name_data[:identifier].to_s
            else
              name_data.to_s
            end
          end

          # Process a value (polymorphic)
          # rubocop:disable Metrics/MethodLength
          def process_value(value)
            return nil unless value
            return value.to_s if value.is_a?(String)

            # Check if it's an array of string parts (concatenated strings)
            if value.is_a?(Array) && value.first.respond_to?(:[]) && value.first[:string]
              # Multiple strings - concatenate them
              return value.map do |part|
                extract_and_unescape_string(part[:string])
              end.join
            end

            return nil unless value.respond_to?(:[])

            # Handle negative numbers
            if value[:negative]
              inner_value = process_value(value[:negative])
              return -inner_value if inner_value.is_a?(Numeric)

              return inner_value
            end

            if value[:string]
              # Single string
              extract_and_unescape_string(value[:string])
            elsif value[:integer]
              value[:integer].to_s.to_i
            elsif value[:float]
              value[:float].to_s.to_f
            elsif value[:identifier]
              # Could be boolean or enum value
              val = value[:identifier].to_s
              case val.downcase
              when "true", "t"
                true
              when "false", "f"
                false
              else
                val # Enum value
              end
            elsif value[:message]
              # Nested message
              fields = normalize_fields(value[:message])
              { "fields" => fields }
            elsif value[:list]
              # List of values
              process_list(value[:list])
            else
              value.to_s
            end
          end
          # rubocop:enable Metrics/MethodLength

          # Extract and unescape a string token
          def extract_and_unescape_string(str_token)
            str = str_token.to_s
            # Remove surrounding quotes
            str = str[1..-2] if str.start_with?('"') && str.end_with?('"')
            str = str[1..-2] if str.start_with?("'") && str.end_with?("'")
            unescape_string(str)
          end

          # Process a list of values
          def process_list(list)
            return [] unless list

            Array(list).map { |item| process_value(item) }
          end

          # Unescape string content
          def unescape_string(str)
            str.gsub('\\n', "\n")
              .gsub('\\t', "\t")
              .gsub('\\r', "\r")
              .gsub('\\"', '"')
              .gsub("\\'", "'")
              .gsub("\\\\", "\\")
          end
        end
      end
    end
  end
end
