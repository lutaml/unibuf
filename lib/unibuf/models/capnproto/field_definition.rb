# frozen_string_literal: true

module Unibuf
  module Models
    module Capnproto
      # Represents a Cap'n Proto field definition
      class FieldDefinition
        attr_reader :name, :ordinal, :type, :default_value

        def initialize(attributes = {})
          @name = attributes[:name] || attributes["name"]
          @ordinal = attributes[:ordinal] || attributes["ordinal"]
          @type = attributes[:type] || attributes["type"]
          @default_value = attributes[:default_value] ||
            attributes["default_value"]
        end

        # Type classification
        def primitive_type?
          type.is_a?(String) && PRIMITIVE_TYPES.include?(type)
        end

        def generic_type?
          type.is_a?(Hash) && type.key?(:generic)
        end

        def user_type?
          type.is_a?(String) && !primitive_type?
        end

        def list_type?
          generic_type? && type[:generic] == "List"
        end

        def element_type
          return nil unless list_type?

          type[:element_type]
        end

        # Validation
        def valid?
          validate!
          true
        rescue ValidationError
          false
        end

        def validate!
          raise ValidationError, "Field name required" unless name
          raise ValidationError, "Field ordinal required" unless ordinal
          raise ValidationError, "Field type required" unless type

          if ordinal.to_i.negative?
            raise ValidationError,
                  "Ordinal must be non-negative"
          end

          true
        end

        def to_h
          {
            name: name,
            ordinal: ordinal,
            type: type,
            default_value: default_value,
          }
        end

        PRIMITIVE_TYPES = %w[
          Void Bool
          Int8 Int16 Int32 Int64
          UInt8 UInt16 UInt32 UInt64
          Float32 Float64
          AnyPointer
        ].freeze
      end
    end
  end
end
