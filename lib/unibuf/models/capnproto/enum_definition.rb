# frozen_string_literal: true

module Unibuf
  module Models
    module Capnproto
      # Represents a Cap'n Proto enum definition
      class EnumDefinition
        attr_reader :name, :values, :annotations

        def initialize(attributes = {})
          @name = attributes[:name] || attributes["name"]
          @values = attributes[:values] || attributes["values"] || {}
          @annotations = Array(
            attributes[:annotations] || attributes["annotations"],
          )
        end

        # Queries
        def value_names
          values.keys
        end

        def ordinals
          values.values
        end

        def find_value(name)
          values[name]
        end

        def find_name_by_ordinal(ordinal)
          values.find { |_name, ord| ord == ordinal }&.first
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

          if values.empty?
            raise ValidationError,
                  "Enum must have at least one value"
          end

          # Check for duplicate ordinals
          ordinal_counts = ordinals.tally
          duplicates = ordinal_counts.select { |_ord, count| count > 1 }
          unless duplicates.empty?
            raise ValidationError,
                  "Duplicate ordinals in enum '#{name}': #{duplicates.keys.join(', ')}"
          end

          true
        end

        def to_h
          {
            name: name,
            values: values,
            annotations: annotations,
          }
        end
      end
    end
  end
end
