# frozen_string_literal: true

module Unibuf
  module Validators
    # Validates field types and values
    # Ensures type safety and Protocol Buffer compliance
    class TypeValidator
      # Type mapping for Protocol Buffer types
      VALID_TYPES = {
        string: [String],
        int32: [Integer],
        int64: [Integer],
        uint32: [Integer],
        uint64: [Integer],
        sint32: [Integer],
        sint64: [Integer],
        fixed32: [Integer],
        fixed64: [Integer],
        sfixed32: [Integer],
        sfixed64: [Integer],
        float: [Float, Integer],
        double: [Float, Integer],
        bool: [TrueClass, FalseClass],
        bytes: [String],
      }.freeze

      class << self
        # Validate a field's type
        # @param field [Field] The field to validate
        # @param expected_type [Symbol] The expected Protocol Buffer type
        # @return [Boolean] true if valid
        # @raise [TypeValidationError] if invalid
        def validate_field(field, expected_type)
          return true if field.value.nil? # Allow nil for optional fields

          valid_classes = VALID_TYPES[expected_type]
          unless valid_classes
            raise TypeValidationError,
                  "Unknown type '#{expected_type}'"
          end

          unless valid_classes.any? { |klass| field.value.is_a?(klass) }
            raise TypeValidationError,
                  "Field '#{field.name}' expected #{expected_type}, " \
                  "got #{field.value.class}"
          end

          # Additional range validation for numeric types
          if numeric_type?(expected_type)
            validate_numeric_range(field,
                                   expected_type)
          end

          true
        end

        # Validate all fields in a message
        # @param message [Message] The message to validate
        # @param schema [Hash] Type schema mapping field names to types
        # @return [Array<String>] List of validation errors
        def validate_message(message, schema = {})
          errors = []

          message.fields_array.each do |field|
            next unless schema.key?(field.name)

            expected_type = schema[field.name]
            begin
              validate_field(field, expected_type)
            rescue TypeValidationError => e
              errors << e.message
            end
          end

          errors
        end

        # Check if a type is numeric
        def numeric_type?(type)
          %i[int32 int64 uint32 uint64 sint32 sint64 fixed32 fixed64 sfixed32
             sfixed64 float double].include?(type)
        end

        # Check if a type is signed
        def signed_type?(type)
          %i[int32 int64 sint32 sint64 sfixed32 sfixed64 float
             double].include?(type)
        end

        # Check if a type is unsigned
        def unsigned_type?(type)
          %i[uint32 uint64 fixed32 fixed64].include?(type)
        end

        private

        def validate_numeric_range(field, expected_type)
          value = field.value
          return unless value.is_a?(Numeric)

          case expected_type
          when :int32, :sint32, :sfixed32
            validate_range(field, value, -2**31, (2**31) - 1)
          when :int64, :sint64, :sfixed64
            validate_range(field, value, -2**63, (2**63) - 1)
          when :uint32, :fixed32
            validate_range(field, value, 0, (2**32) - 1)
          when :uint64, :fixed64
            validate_range(field, value, 0, (2**64) - 1)
          end
        end

        def validate_range(field, value, min, max)
          return if value.between?(min, max)

          raise TypeValidationError,
                "Field '#{field.name}' value #{value} out of range [#{min}, #{max}]"
        end
      end
    end
  end
end
