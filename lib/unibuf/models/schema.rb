# frozen_string_literal: true

module Unibuf
  module Models
    # Represents a Protocol Buffer schema (.proto file)
    class Schema
      attr_reader :syntax, :package, :imports, :messages, :enums

      def initialize(attributes = {})
        @syntax = attributes[:syntax] || attributes["syntax"] || "proto3"
        @package = attributes[:package] || attributes["package"]
        @imports = Array(attributes[:imports] || attributes["imports"])
        @messages = Array(attributes[:messages] || attributes["messages"])
        @enums = Array(attributes[:enums] || attributes["enums"])
      end

      # Queries
      def find_message(name)
        messages.find { |msg| msg.name == name }
      end

      def find_enum(name)
        enums.find { |enum| enum.name == name }
      end

      def message_names
        messages.map(&:name)
      end

      def enum_names
        enums.map(&:name)
      end

      # Validation
      def valid?
        validate!
        true
      rescue ValidationError
        false
      end

      def validate!
        raise ValidationError, "Syntax must be proto3" unless syntax == "proto3"

        messages.each(&:validate!)
        enums.each(&:validate!)

        true
      end

      # Find type (message or enum)
      def find_type(name)
        find_message(name) || find_enum(name)
      end

      def to_h
        {
          syntax: syntax,
          package: package,
          imports: imports,
          messages: messages.map(&:to_h),
          enums: enums.map(&:to_h),
        }
      end
    end
  end
end
