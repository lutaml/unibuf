# frozen_string_literal: true

module Unibuf
  module Models
    module Flatbuffers
      # Represents a FlatBuffers table definition
      class TableDefinition
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

        def has_metadata?(key)
          metadata.key?(key)
        end

        def get_metadata(key)
          metadata[key]
        end

        # Classification
        def has_vectors?
          fields.any?(&:vector?)
        end

        def has_nested_tables?
          fields.any? { |f| f.type_kind == :table }
        end

        # Validation
        def valid?
          validate!
          true
        rescue ValidationError
          false
        end

        def validate!
          raise ValidationError, "Table name required" unless name

          if fields.empty?
            raise ValidationError,
                  "Table must have at least one field"
          end

          fields.each(&:validate!)

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
