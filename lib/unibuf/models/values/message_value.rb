# frozen_string_literal: true

require_relative "base_value"

module Unibuf
  module Models
    module Values
      # Represents a nested message value
      # Delegates to Message model for message-specific behavior
      class MessageValue < BaseValue
        attr_reader :message

        def initialize(raw_value)
          super
          @message = Message.new(raw_value)
        end

        def message?
          true
        end

        # Delegation to message
        def fields
          message.fields
        end

        def field_count
          message.field_count
        end

        def find_field(name)
          message.find_field(name)
        end

        def field_names
          message.field_names
        end

        # Serialization - delegates to message
        def to_textproto(indent: 0)
          indent_str = "  " * indent
          nested_content = message.to_textproto(indent: indent + 1)
          "{\n#{nested_content}\n#{indent_str}}"
        end

        # Validation
        def validate!
          unless raw_value.is_a?(Hash) && raw_value.key?("fields")
            raise InvalidValueError,
                  "MessageValue requires hash with 'fields' key"
          end

          message.validate! if message.respond_to?(:validate!)
          true
        end

        # Deep equality
        def ==(other)
          return false unless other.is_a?(MessageValue)

          message == other.message
        end

        def hash
          [self.class, message].hash
        end
      end
    end
  end
end
