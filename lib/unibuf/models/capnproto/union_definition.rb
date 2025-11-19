# frozen_string_literal: true

module Unibuf
  module Models
    module Capnproto
      # Represents a Cap'n Proto union definition (discriminated union)
      class UnionDefinition
        attr_reader :fields

        def initialize(attributes = {})
          @fields = Array(attributes[:fields] || attributes["fields"])
        end

        # Queries
        def field_names
          fields.map(&:name)
        end

        def ordinals
          fields.map(&:ordinal)
        end

        def find_field(name)
          fields.find { |f| f.name == name }
        end

        # Validation
        def valid?
          validate!
          true
        rescue ValidationError
          false
        end

        def validate!
          if fields.length < 2
            raise ValidationError,
                  "Union must have at least two fields"
          end

          # Check for duplicate ordinals
          ordinal_counts = ordinals.tally
          duplicates = ordinal_counts.select { |_ord, count| count > 1 }
          unless duplicates.empty?
            raise ValidationError,
                  "Duplicate ordinals in union: #{duplicates.keys.join(', ')}"
          end

          fields.each(&:validate!)

          true
        end

        def to_h
          {
            fields: fields.map(&:to_h),
          }
        end
      end
    end
  end
end
