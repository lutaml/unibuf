# frozen_string_literal: true

require_relative "base_value"

module Unibuf
  module Models
    module Values
      # Represents a map/dictionary value (key-value pairs)
      # Provides hash-like interface with type safety
      class MapValue < BaseValue
        def map?
          true
        end

        # Hash-like interface
        def key
          raw_value["key"]
        end

        def value
          raw_value["value"]
        end

        def to_h
          { key => value }
        end

        # Type checking
        def key_type
          key.class
        end

        def value_type
          value.class
        end

        def scalar_value?
          !value.is_a?(Hash) && !value.is_a?(Array)
        end

        def message_value?
          value.is_a?(Hash) && value.key?("fields")
        end

        # Serialization
        def to_textproto(indent: 0)
          indent_str = "  " * indent
          key_str = format_value(key)
          val_str = format_value(value)

          "{\n" \
            "#{indent_str}  key: #{key_str}\n" \
            "#{indent_str}  value: #{val_str}\n" \
            "#{indent_str}}"
        end

        # Validation
        def validate!
          unless raw_value.is_a?(Hash)
            raise InvalidValueError,
                  "MapValue requires hash, got #{raw_value.class}"
          end
          unless raw_value.key?("key") && raw_value.key?("value")
            raise InvalidValueError, "MapValue requires 'key' and 'value' keys"
          end

          true
        end

        # Comparison
        def ==(other)
          return false unless other.is_a?(MapValue)

          key == other.key && value == other.value
        end

        def hash
          [self.class, key, value].hash
        end

        private

        def format_value(val)
          case val
          when String
            "\"#{val.gsub('\\', '\\\\').gsub('"', '\"')}\""
          when Numeric, TrueClass, FalseClass
            val.to_s
          when Hash
            if val.key?("fields")
              msg = Models::Message.new(val)
              "{\n#{msg.to_textproto(indent: 1)}\n}"
            else
              val.to_s
            end
          else
            val.to_s
          end
        end
      end
    end
  end
end
