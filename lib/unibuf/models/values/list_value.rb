# frozen_string_literal: true

require_relative "base_value"

module Unibuf
  module Models
    module Values
      # Represents a list/array value (repeated fields)
      # Provides array-like interface with type safety
      class ListValue < BaseValue
        def list?
          true
        end

        # Array-like interface
        def size
          items.size
        end

        def empty?
          items.empty?
        end

        def [](index)
          items[index]
        end

        def each(&)
          items.each(&)
        end

        def map(&)
          items.map(&)
        end

        def select(&)
          items.select(&)
        end

        def first
          items.first
        end

        def last
          items.last
        end

        # Type checking
        def homogeneous?
          return true if items.empty?

          first_type = items.first.class
          items.all?(first_type)
        end

        def all_scalars?
          items.all? do |item|
            item.is_a?(String) || item.is_a?(Numeric) || item.is_a?(TrueClass) || item.is_a?(FalseClass)
          end
        end

        def all_messages?
          items.all? { |item| item.is_a?(Hash) && item.key?("fields") }
        end

        # Serialization
        def to_textproto(indent: 0)
          return "[]" if empty?

          if all_scalars? && size < 5
            # Short inline format for small scalar lists
            formatted = items.map { |item| format_item(item) }
            "[#{formatted.join(', ')}]"
          else
            # Multi-line format for complex or large lists
            indent_str = "  " * indent
            formatted = items.map { |item| format_item(item) }
            "[\n#{indent_str}  #{formatted.join(",\n#{indent_str}  ")}\n#{indent_str}]"
          end
        end

        # Validation
        def validate!
          unless raw_value.is_a?(Array)
            raise InvalidValueError,
                  "ListValue requires array, got #{raw_value.class}"
          end

          true
        end

        private

        def items
          @items ||= Array(raw_value)
        end

        def format_item(item)
          case item
          when String
            "\"#{item.gsub('\\', '\\\\').gsub('"', '\"')}\""
          when Numeric, TrueClass, FalseClass
            item.to_s
          when Hash
            msg = Models::Message.new(item)
            msg.to_textproto
          else
            item.to_s
          end
        end
      end
    end
  end
end
