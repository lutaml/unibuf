# frozen_string_literal: true

module Unibuf
  module Models
    module Flatbuffers
      # Represents a field in a FlatBuffers table or struct
      class FieldDefinition
        attr_reader :name, :type, :default_value, :metadata

        def initialize(attributes = {})
          @name = attributes[:name] || attributes["name"]
          @type = attributes[:type] || attributes["type"]
          @default_value = attributes[:default_value] || attributes["default_value"]
          @metadata = attributes[:metadata] || attributes["metadata"] || {}
        end

        # Type classification
        def scalar?
          SCALAR_TYPES.include?(type)
        end

        def vector?
          type.is_a?(Hash) && type[:vector]
        end

        def user_type?
          !scalar? && !vector?
        end

        def type_kind
          return :vector if vector?
          return :scalar if scalar?

          # Assume user type (table, struct, enum)
          :table
        end

        def vector_element_type
          return nil unless vector?

          type[:vector]
        end

        # Metadata queries
        def deprecated?
          metadata[:deprecated] == true
        end

        def required?
          metadata[:required] == true
        end

        def id
          metadata[:id]
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
          raise ValidationError, "Field type required" unless type

          true
        end

        def to_h
          {
            name: name,
            type: type,
            default_value: default_value,
            metadata: metadata,
          }.compact
        end

        private

        SCALAR_TYPES = %w[
          byte ubyte short ushort int uint long ulong
          float double bool
        ].freeze
      end
    end
  end
end