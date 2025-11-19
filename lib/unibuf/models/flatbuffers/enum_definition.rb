# frozen_string_literal: true

module Unibuf
  module Models
    module Flatbuffers
      # Represents a FlatBuffers enum definition
      class EnumDefinition
        attr_reader :name, :type, :values, :metadata

        def initialize(attributes = {})
          @name = attributes[:name] || attributes["name"]
          @type = attributes[:type] || attributes["type"] || "int"
          @values = attributes[:values] || attributes["values"] || {}
          @metadata = attributes[:metadata] || attributes["metadata"] || {}
        end

        # Queries
        def find_value_by_name(value_name)
          values[value_name]
        end

        def find_name_by_value(value)
          values.key(value)
        end

        def value_names
          values.keys
        end

        def value_numbers
          values.values
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
          raise ValidationError, "Enum must have at least one value" if values.empty?

          # Check for duplicate values
          if values.values.uniq.size != values.values.size
            raise ValidationError, "Enum '#{name}' has duplicate values"
          end

          true
        end

        def to_h
          {
            name: name,
            type: type,
            values: values,
            metadata: metadata,
          }
        end
      end
    end
  end
end