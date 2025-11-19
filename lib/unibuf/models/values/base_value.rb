# frozen_string_literal: true

module Unibuf
  module Models
    module Values
      # Base class for all value types in Protocol Buffer messages
      # Follows Open/Closed principle - open for extension, closed for modification
      class BaseValue
        attr_reader :raw_value

        def initialize(raw_value)
          @raw_value = raw_value
          validate!
        end

        # Type identification - MECE classification
        def scalar?
          false
        end

        def message?
          false
        end

        def list?
          false
        end

        def map?
          false
        end

        # Serialization - template method pattern
        def to_textproto(indent: 0)
          raise NotImplementedError, "Subclasses must implement to_textproto"
        end

        # Validation - template method pattern
        def validate!
          # Subclasses can override for specific validation
          true
        end

        # Equality
        def ==(other)
          return false unless other.is_a?(self.class)

          raw_value == other.raw_value
        end

        def hash
          [self.class, raw_value].hash
        end

        # Factory method - creates appropriate value type
        def self.from_raw(raw_value)
          case raw_value
          when Hash
            if raw_value.key?("fields")
              MessageValue.new(raw_value)
            elsif raw_value.key?("key") && raw_value.key?("value")
              MapValue.new(raw_value)
            else
              raise InvalidValueError,
                    "Unknown hash structure: #{raw_value.keys}"
            end
          when Array
            ListValue.new(raw_value)
          when String, Integer, Float, TrueClass, FalseClass, NilClass
            ScalarValue.new(raw_value)
          else
            raise InvalidValueError, "Unknown value type: #{raw_value.class}"
          end
        end
      end
    end
  end
end
