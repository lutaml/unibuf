# frozen_string_literal: true

module Unibuf
  module Models
    # Represents a message type definition from a .proto schema
    # Used for schema-based validation of textproto files
    class MessageDefinition
      attr_reader :name, :fields, :nested_messages, :nested_enums

      def initialize(attributes = {})
        @name = attributes[:name] || attributes["name"]
        @fields = Array(attributes[:fields] || attributes["fields"])
        @nested_messages = Array(attributes[:nested_messages] || attributes["nested_messages"])
        @nested_enums = Array(attributes[:nested_enums] || attributes["nested_enums"])
      end

      # Queries
      def find_field(name)
        fields.find { |f| f.name == name }
      end

      def find_field_by_number(number)
        fields.find { |f| f.number == number }
      end

      def find_nested_message(name)
        nested_messages.find { |m| m.name == name }
      end

      def find_nested_enum(name)
        nested_enums.find { |e| e.name == name }
      end

      def field_names
        fields.map(&:name)
      end

      def field_numbers
        fields.map(&:number)
      end

      # Classification
      def has_repeated_fields?
        fields.any?(&:repeated?)
      end

      def has_nested_messages?
        nested_messages.any?
      end

      def has_maps?
        fields.any?(&:map?)
      end

      # Validation
      def valid?
        validate!
        true
      rescue ValidationError
        false
      end

      def validate!
        raise ValidationError, "Message name required" unless name

        # Check for duplicate field numbers
        numbers = field_numbers
        duplicates = numbers.select { |n| numbers.count(n) > 1 }.uniq
        if duplicates.any?
          raise ValidationError,
                "Duplicate field numbers: #{duplicates.join(', ')}"
        end

        # Validate all fields
        fields.each(&:validate!)

        # Validate nested messages
        nested_messages.each(&:validate!)
        nested_enums.each(&:validate!)

        true
      end

      def valid_field_value?(field_name, value)
        field_def = find_field(field_name)
        return false unless field_def

        field_def.valid_value?(value)
      end

      # Transformation
      def to_h
        {
          name: name,
          fields: fields.map(&:to_h),
          nested_messages: nested_messages.map(&:to_h),
          nested_enums: nested_enums.map(&:to_h),
        }
      end
    end
  end
end
