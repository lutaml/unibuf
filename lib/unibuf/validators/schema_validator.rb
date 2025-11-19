# frozen_string_literal: true

module Unibuf
  module Validators
    # Validates Protocol Buffer messages against Proto3 schemas
    # Ensures textproto files conform to their schema definitions
    class SchemaValidator
      attr_reader :schema

      def initialize(schema)
        @schema = schema
      end

      # Validate a message against the schema
      # @param message [Message] The textproto message
      # @param message_type [String] Expected message type name
      # @return [Boolean] true if valid
      # @raise [SchemaValidationError] if invalid
      def validate!(message, message_type = nil)
        errors = validate(message, message_type)

        return true if errors.empty?

        raise SchemaValidationError,
              "Schema validation failed:\n#{errors.join("\n")}"
      end

      # Validate and return errors
      # @param message [Message] The textproto message
      # @param message_type [String] Expected message type name
      # @return [Array<String>] List of validation errors
      def validate(message, message_type = nil)
        errors = []

        # Find message definition
        msg_def = find_message_definition(message_type)
        unless msg_def
          return ["Unknown message type: #{message_type}"]
        end

        # Validate each field in the message using public fields
        Array(message.fields).each do |field|
          field_errors = validate_field(field, msg_def)
          errors.concat(field_errors)
        end

        # Check for required fields
        required_errors = check_required_fields(message, msg_def)
        errors.concat(required_errors)

        errors
      end

      private

      def find_message_definition(type_name)
        return schema.messages.first if type_name.nil? && schema.messages.size == 1

        schema.find_message(type_name)
      end

      def validate_field(field, msg_def)
        errors = []

        # Check if field exists in schema
        field_def = msg_def.find_field(field.name)
        unless field_def
          errors << "Unknown field '#{field.name}' in message '#{msg_def.name}'"
          return errors
        end

        # Validate field value type
        unless field_def.valid_value?(field.value)
          errors << "Invalid value for field '#{field.name}': " \
                    "expected #{field_def.type}, got #{field.value.class}"
        end

        # Validate nested messages recursively
        if field.message_field? && field_def.message_type?
          nested_msg = field.as_message
          nested_def = schema.find_message(field_def.type)

          if nested_def
            nested_errors = validate(nested_msg, field_def.type)
            errors.concat(nested_errors.map { |e| "  #{field.name}.#{e}" })
          end
        end

        errors
      end

      def check_required_fields(message, msg_def)
        errors = []

        # In proto3, all fields are optional by default
        # We only check required fields if explicitly marked
        msg_def.fields.each do |field_def|
          next unless field_def.required?

          field = message.find_field(field_def.name)
          unless field
            errors << "Required field '#{field_def.name}' missing in #{msg_def.name}"
          end
        end

        errors
      end
    end
  end
end
