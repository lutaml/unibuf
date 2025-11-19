# frozen_string_literal: true

module Unibuf
  module Models
    module Capnproto
      # Represents a Cap'n Proto interface definition (for RPC)
      class InterfaceDefinition
        attr_reader :name, :methods, :annotations

        def initialize(attributes = {})
          @name = attributes[:name] || attributes["name"]
          @methods = Array(attributes[:methods] || attributes["methods"])
          @annotations = Array(
            attributes[:annotations] || attributes["annotations"],
          )
        end

        # Queries
        def find_method(name)
          methods.find { |m| m.name == name }
        end

        def method_names
          methods.map(&:name)
        end

        def ordinals
          methods.map(&:ordinal)
        end

        # Validation
        def valid?
          validate!
          true
        rescue ValidationError
          false
        end

        def validate!
          raise ValidationError, "Interface name required" unless name

          if methods.empty?
            raise ValidationError,
                  "Interface must have at least one method"
          end

          # Check for duplicate ordinals
          ordinal_counts = ordinals.tally
          duplicates = ordinal_counts.select { |_ord, count| count > 1 }
          unless duplicates.empty?
            raise ValidationError,
                  "Duplicate ordinals in interface '#{name}': #{duplicates.keys.join(', ')}"
          end

          methods.each(&:validate!)

          true
        end

        def to_h
          {
            name: name,
            methods: methods.map(&:to_h),
            annotations: annotations,
          }
        end
      end
    end
  end
end
