# frozen_string_literal: true

module Unibuf
  module Models
    # Represents a field in a Protocol Buffer message
    # Rich domain model with behavior, not just data
    # Using plain Ruby class for polymorphic value support
    class Field
      attr_reader :name, :value, :is_map

      def initialize(attributes = {})
        @name = attributes["name"] || attributes[:name]
        @value = attributes["value"] || attributes[:value]
        @is_map = attributes["is_map"] || attributes[:is_map] || false
      end

      # Type queries - MECE classification
      def message_field?
        value.is_a?(Hash) && value.key?("fields")
      end

      def scalar_field?
        !message_field? && !map_field? && !list_field?
      end

      def map_field?
        is_map == true || (value.is_a?(Hash) && value.key?("key") && value.key?("value"))
      end

      def list_field?
        value.is_a?(Array)
      end

      # Value type detection
      def string_value?
        value.is_a?(String)
      end

      def integer_value?
        value.is_a?(Integer)
      end

      def float_value?
        value.is_a?(Float)
      end

      def boolean_value?
        value.is_a?(TrueClass) || value.is_a?(FalseClass)
      end

      # Value accessors with type coercion
      def as_string
        return value.to_s if scalar_field?

        raise TypeCoercionError, "Cannot convert #{value.class} to String"
      end

      def as_integer
        return value if integer_value?
        return value.to_i if string_value? && value.match?(/^\d+$/)

        raise TypeCoercionError, "Cannot convert #{value.class} to Integer"
      end

      def as_float
        return value if float_value?
        return value.to_f if string_value? && value.match?(/^\d+\.?\d*$/)

        raise TypeCoercionError, "Cannot convert #{value.class} to Float"
      end

      def as_boolean
        return value if boolean_value?
        return true if string_value? && value == "true"
        return false if string_value? && value == "false"

        raise TypeCoercionError, "Cannot convert #{value.class} to Boolean"
      end

      def as_message
        return Models::Message.new(value) if message_field?

        raise TypeCoercionError, "Field is not a message type"
      end

      def as_list
        return value if list_field?

        raise TypeCoercionError, "Field is not a list type"
      end

      # Serialize to textproto format
      def to_textproto(indent: 0)
        indent_str = "  " * indent

        if message_field?
          # Nested message: name { fields }
          nested_msg = as_message
          nested_content = nested_msg.to_textproto(indent: indent + 1)
          "#{indent_str}#{name} {\n#{nested_content}\n#{indent_str}}"
        elsif map_field?
          # Map entry: name { key: "k" value: "v" }
          key_str = format_value(value["key"])
          val_str = format_value(value["value"])
          "#{indent_str}#{name} {\n#{indent_str}  key: #{key_str}\n#{indent_str}  value: #{val_str}\n#{indent_str}}"
        elsif list_field?
          # List values: each item on separate line with same field name
          value.map do |item|
            "#{indent_str}#{name}: #{format_value(item)}"
          end.join("\n")
        else
          # Scalar field: name: value
          "#{indent_str}#{name}: #{format_value(value)}"
        end
      end

      # Comparison
      def ==(other)
        return false unless other.is_a?(Field)

        name == other.name && value == other.value
      end

      def hash
        [name, value].hash
      end

      private

      # Format a value for textproto output
      def format_value(val)
        case val
        when String
          escape_string(val)
        when Integer, Float
          val.to_s
        when TrueClass, FalseClass
          val.to_s
        when Hash
          # Nested message
          msg = Models::Message.new(val)
          "{\n#{msg.to_textproto(indent: 1)}\n}"
        else
          val.to_s
        end
      end

      # Escape and quote a string for textproto
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
