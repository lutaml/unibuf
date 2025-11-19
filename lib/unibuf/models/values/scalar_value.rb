# frozen_string_literal: true

require_relative "base_value"

module Unibuf
  module Models
    module Values
      # Scalar value types: string, integer, float, boolean
      # Immutable value object with type coercion
      class ScalarValue < BaseValue
        def scalar?
          true
        end

        # Type queries - MECE
        def string?
          raw_value.is_a?(String)
        end

        def integer?
          raw_value.is_a?(Integer)
        end

        def float?
          raw_value.is_a?(Float)
        end

        def boolean?
          raw_value.is_a?(TrueClass) || raw_value.is_a?(FalseClass)
        end

        def nil?
          raw_value.nil?
        end

        # Type coercion with validation
        def as_string
          raw_value.to_s
        end

        def as_integer
          return raw_value if integer?
          return raw_value.to_i if string? && raw_value.match?(/^-?\d+$/)

          raise TypeCoercionError,
                "Cannot convert #{raw_value.class} to Integer"
        end

        def as_float
          return raw_value if float?
          return raw_value.to_f if integer?
          return raw_value.to_f if string? && raw_value.match?(/^-?\d+\.?\d*$/)

          raise TypeCoercionError, "Cannot convert #{raw_value.class} to Float"
        end

        def as_boolean
          return raw_value if boolean?
          return true if string? && %w[true t 1].include?(raw_value.downcase)
          return false if string? && %w[false f 0].include?(raw_value.downcase)
          return true if integer? && raw_value == 1
          return false if integer? && raw_value.zero?

          raise TypeCoercionError,
                "Cannot convert #{raw_value.class} to Boolean"
        end

        # Serialization
        def to_textproto(indent: 0)
          format_scalar(raw_value)
        end

        # Validation
        def validate!
          unless [String, Integer, Float, TrueClass, FalseClass,
                  NilClass].any? do |t|
            raw_value.is_a?(t)
          end
            raise InvalidValueError, "Invalid scalar type: #{raw_value.class}"
          end

          true
        end

        private

        def format_scalar(value)
          case value
          when String
            escape_string(value)
          when Integer, Float
            value.to_s
          when TrueClass, FalseClass
            value.to_s
          when NilClass
            '""'
          else
            value.to_s
          end
        end

        def escape_string(str)
          escaped = str.gsub("\\", "\\\\")
            .gsub('"', '\"')
            .gsub("\n", '\\n')
            .gsub("\t", '\\t')
            .gsub("\r", '\\r')
          "\"#{escaped}\""
        end
      end
    end
  end
end
