# frozen_string_literal: true

module Unibuf
  module Models
    # Represents an enum type definition from a Proto3 schema
    class EnumDefinition
      attr_reader :name, :values

      def initialize(attributes = {})
        @name = attributes[:name] || attributes["name"]
        @values = attributes[:values] || attributes["values"] || {}
      end

      # Queries
      def value_names
        values.keys
      end

      def value_numbers
        values.values
      end

      def find_value_by_name(name)
        values[name]
      end

      def find_name_by_value(number)
        values.key(number)
      end

      # Validation
      def valid?
        validate!
        true
      rescue ValidationError
        false
      end

      def validate!
        raise ValidationError, "Enum name required" unless name

        if values.empty?
          raise ValidationError,
                "Enum must have at least one value"
        end

        # Check for duplicate values
        nums = value_numbers
        duplicates = nums.select { |n| nums.count(n) > 1 }.uniq
        if duplicates.any?
          raise ValidationError,
                "Duplicate enum values: #{duplicates.join(', ')}"
        end

        true
      end

      def valid_value?(value)
        case value
        when String
          value_names.include?(value)
        when Integer
          value_numbers.include?(value)
        else
          false
        end
      end

      # Transformation
      def to_h
        {
          name: name,
          values: values,
        }
      end
    end
  end
end
