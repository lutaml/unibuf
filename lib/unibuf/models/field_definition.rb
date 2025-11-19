# frozen_string_literal: true

module Unibuf
  module Models
    # Represents a field definition from a Proto3 schema
    # Used for type checking and validation
    class FieldDefinition
      attr_reader :name, :type, :number, :label, :options

      # Map types are stored as special attributes
      attr_reader :key_type, :value_type

      def initialize(attributes = {})
        @name = attributes[:name] || attributes["name"]
        @type = attributes[:type] || attributes["type"]
        @number = attributes[:number] || attributes["number"]
        @label = attributes[:label] || attributes["label"]
        @options = attributes[:options] || attributes["options"] || {}

        # For map fields
        @key_type = attributes[:key_type] || attributes["key_type"]
        @value_type = attributes[:value_type] || attributes["value_type"]
      end

      # Type queries - MECE
      def repeated?
        label == "repeated"
      end

      def optional?
        label == "optional" || label.nil?
      end

      def required?
        label == "required"
      end

      def map?
        !key_type.nil? && !value_type.nil?
      end

      def message_type?
        !scalar_type? && !map?
      end

      def scalar_type?
        SCALAR_TYPES.include?(type)
      end

      # Scalar types from Protocol Buffers
      SCALAR_TYPES = %w[
        double float int32 int64 uint32 uint64
        sint32 sint64 fixed32 fixed64 sfixed32 sfixed64
        bool string bytes
      ].freeze

      # Validation
      def valid?
        validate!
        true
      rescue ValidationError
        false
      end

      def validate!
        raise ValidationError, "Field name required" unless name
        raise ValidationError, "Field type required" unless type
        raise ValidationError, "Field number required" unless number

        unless number.positive?
          raise ValidationError,
                "Field number must be positive"
        end

        true
      end

      def valid_value?(value)
        return true if value.nil? && optional?

        case type
        when "string"
          value.is_a?(String)
        when "int32", "sint32", "sfixed32"
          value.is_a?(Integer) && value >= -2**31 && value < 2**31
        when "int64", "sint64", "sfixed64"
          value.is_a?(Integer) && value >= -2**63 && value < 2**63
        when "uint32", "fixed32"
          value.is_a?(Integer) && value >= 0 && value < 2**32
        when "uint64", "fixed64"
          value.is_a?(Integer) && value >= 0 && value < 2**64
        when "float", "double"
          value.is_a?(Numeric)
        when "bool"
          value.is_a?(TrueClass) || value.is_a?(FalseClass)
        when "bytes"
          value.is_a?(String)
        else
          # Message type - allow hash or Message object
          value.is_a?(Hash) || value.is_a?(Message)
        end
      end

      # Transformation
      def to_h
        hash = {
          name: name,
          type: type,
          number: number,
        }
        hash[:label] = label if label
        hash[:key_type] = key_type if key_type
        hash[:value_type] = value_type if value_type
        hash[:options] = options unless options.empty?
        hash
      end
    end
  end
end
