# frozen_string_literal: true

require_relative "field"

module Unibuf
  module Models
    # Represents a Protocol Buffer message
    # Rich domain model with comprehensive behavior
    class Message
      attr_reader :fields

      def initialize(attributes = {})
        fields_data = attributes["fields"] || attributes[:fields] || []
        @fields = Array(fields_data).map do |field_data|
          field_data.is_a?(Field) ? field_data : Field.new(field_data)
        end
      end

      # Factory method from hash
      def self.from_hash(hash)
        new(hash)
      end

      # Classification - MECE principle
      def nested?
        fields_array.any?(&:message_field?)
      end

      def repeated_fields?
        # Check if any field name appears multiple times
        field_names = fields_array.map(&:name)
        field_names.uniq.size != field_names.size
      end

      def maps?
        fields_array.any?(&:map_field?)
      end

      def scalar_only?
        fields_array.all?(&:scalar_field?)
      end

      def empty?
        fields_array.empty?
      end

      def complete?
        # Message is complete if it has at least one field
        !empty?
      end

      # Query methods
      def find_field(name)
        fields_array.find { |f| f.name == name }
      end

      def find_fields(name)
        fields_array.select { |f| f.name == name }
      end

      def field_names
        fields_array.map(&:name).uniq
      end

      def field_count
        fields_array.size
      end

      def repeated_field_names
        field_names.select { |name| find_fields(name).size > 1 }
      end

      def map_fields
        fields_array.select(&:map_field?)
      end

      def nested_messages
        fields_array.select(&:message_field?).map(&:as_message)
      end

      # Traversal methods (Milestone 3)
      def traverse_depth_first(&block)
        return enum_for(:traverse_depth_first) unless block

        fields_array.each do |field|
          yield field
          if field.message_field?
            field.as_message.traverse_depth_first(&block)
          end
        end
      end

      def traverse_breadth_first
        return enum_for(:traverse_breadth_first) unless block_given?

        queue = fields_array.dup

        until queue.empty?
          field = queue.shift
          yield field

          if field.message_field?
            queue.concat(field.as_message.fields_array)
          end
        end
      end

      def all_fields_recursive
        traverse_depth_first.to_a
      end

      def depth
        return 0 if empty?
        return 0 unless nested?

        nested_messages.map { |msg| msg.depth + 1 }.max
      end

      # Validation methods (Milestone 3)
      def valid?
        validate!
        true
      rescue ValidationError
        false
      end

      def validate!
        validation_errors.each do |error|
          raise ValidationError, error
        end
        true
      end

      def validation_errors
        errors = []

        fields_array.each do |field|
          # Check for nil values
          errors << "Field '#{field.name}' has nil value" if field.value.nil?

          # Validate nested messages
          if field.message_field?
            begin
              field.as_message.validate!
            rescue ValidationError => e
              errors << "Nested message '#{field.name}': #{e.message}"
            end
          end
        end

        errors
      end

      # Transformation methods
      def to_h
        {
          "fields" => fields_array.map do |field|
            {
              "name" => field.name,
              "value" => field.value,
            }
          end,
        }
      end

      def to_json(*args)
        require "json"
        to_h.to_json(*args)
      end

      def to_yaml
        require "yaml"
        to_h.to_yaml
      end

      # Serialize to textproto format
      def to_textproto(indent: 0)
        lines = fields_array.map do |field|
          field.to_textproto(indent: indent)
        end

        lines.join("\n")
      end

      # Serialize to binary Protocol Buffer format
      # @param schema [Models::Schema] The schema defining the message structure
      # @param message_type [String] The message type name from schema
      # @return [String] Binary data
      def to_binary(schema:, message_type: nil)
        require_relative "../serializers/binary_serializer"
        serializer = Serializers::BinarySerializer.new(schema)
        serializer.serialize(self, message_type: message_type)
      end

      # Comparison
      def ==(other)
        return false unless other.is_a?(Message)

        fields_array == other.send(:fields_array)
      end

      def hash
        fields_array.hash
      end

      protected

      def fields_array
        @fields || []
      end
    end
  end
end
