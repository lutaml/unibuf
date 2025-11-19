# frozen_string_literal: true

module Unibuf
  module Models
    module Flatbuffers
      # Represents a FlatBuffers union definition
      # Unions represent a choice between multiple table types
      class UnionDefinition
        attr_reader :name, :types, :metadata

        def initialize(attributes = {})
          @name = attributes[:name] || attributes["name"]
          @types = Array(attributes[:types] || attributes["types"])
          @metadata = attributes[:metadata] || attributes["metadata"] || {}
        end

        # Queries
        def includes_type?(type_name)
          types.include?(type_name)
        end

        def type_count
          types.size
        end

        # Validation
        def valid?
          validate!
          true
        rescue ValidationError
          false
        end

        def validate!
          raise ValidationError, "Union name required" unless name

          if types.empty?
            raise ValidationError,
                  "Union must have at least one type"
          end

          # Check for duplicate types
          if types.uniq.size != types.size
            raise ValidationError, "Union '#{name}' has duplicate types"
          end

          true
        end

        def to_h
          {
            name: name,
            types: types,
            metadata: metadata,
          }
        end
      end
    end
  end
end
