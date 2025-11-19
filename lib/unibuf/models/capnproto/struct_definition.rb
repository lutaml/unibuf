# frozen_string_literal: true

module Unibuf
  module Models
    module Capnproto
      # Represents a Cap'n Proto struct definition
      class StructDefinition
        attr_reader :name, :fields, :unions, :groups, :nested_structs,
                    :nested_enums, :nested_interfaces, :annotations

        def initialize(attributes = {})
          @name = attributes[:name] || attributes["name"]
          @fields = Array(attributes[:fields] || attributes["fields"])
          @unions = Array(attributes[:unions] || attributes["unions"])
          @groups = Array(attributes[:groups] || attributes["groups"])
          @nested_structs = Array(
            attributes[:nested_structs] || attributes["nested_structs"],
          )
          @nested_enums = Array(
            attributes[:nested_enums] || attributes["nested_enums"],
          )
          @nested_interfaces = Array(
            attributes[:nested_interfaces] || attributes["nested_interfaces"],
          )
          @annotations = Array(
            attributes[:annotations] || attributes["annotations"],
          )
        end

        # Queries
        def find_field(name)
          fields.find { |f| f.name == name }
        end

        def find_union(name)
          unions.find { |u| u.name == name }
        end

        def field_names
          fields.map(&:name)
        end

        def ordinals
          fields.map(&:ordinal)
        end

        def max_ordinal
          ordinals.max || -1
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

          if fields.empty? && unions.empty?
            raise ValidationError,
                  "Struct must have at least one field"
          end

          # Check for duplicate ordinals
          ordinal_counts = ordinals.tally
          duplicates = ordinal_counts.select { |_ord, count| count > 1 }
          unless duplicates.empty?
            raise ValidationError,
                  "Duplicate ordinals in struct '#{name}': #{duplicates.keys.join(', ')}"
          end

          fields.each(&:validate!)
          unions.each(&:validate!)

          true
        end

        def to_h
          {
            name: name,
            fields: fields.map(&:to_h),
            unions: unions.map(&:to_h),
            groups: groups.map(&:to_h),
            nested_structs: nested_structs.map(&:to_h),
            nested_enums: nested_enums.map(&:to_h),
            nested_interfaces: nested_interfaces.map(&:to_h),
            annotations: annotations,
          }
        end
      end
    end
  end
end
