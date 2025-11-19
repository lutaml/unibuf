# frozen_string_literal: true

module Unibuf
  module Models
    module Flatbuffers
      # Represents a FlatBuffers struct definition
      # Structs are fixed-size, stored inline (no vtable)
      class StructDefinition
        attr_reader :name, :fields, :metadata

        def initialize(attributes = {})
          @name = attributes[:name] || attributes["name"]
          @fields = Array(attributes[:fields] || attributes["fields"])
          @metadata = attributes[:metadata] || attributes["metadata"] || {}
        end

        # Queries
        def find_field(field_name)
          fields.find { |f| f.name == field_name }
        end

        def field_names
          fields.map(&:name)
        end

        # Classification
        def fixed_size?
          # Structs are always fixed size
          true
        end

        # Validation
        def valid?
          validate!
          true
        rescue ValidationError
          false
        end

        def validate!
          raise ValidationError, "Struct name required" unless name
          raise ValidationError, "Struct must have at least one field" if fields.empty?

          # Structs cannot contain vectors or other non-scalar types
          fields.each do |field|
            field.validate!
            if field.vector?
              raise ValidationError,
                    "Struct '#{name}' field '#{field.name}' cannot be a vector"
            end
          end

          true
        end

        def to_h
          {
            name: name,
            fields: fields.map(&:to_h),
            metadata: metadata,
          }
        end
      end
    end
  end
end