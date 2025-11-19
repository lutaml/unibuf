# frozen_string_literal: true

module Unibuf
  module Models
    module Flatbuffers
      # Represents a FlatBuffers schema (.fbs file)
      class Schema
        attr_reader :namespace, :includes, :tables, :structs, :enums, :unions,
                    :root_type, :file_identifier, :file_extension, :attributes

        def initialize(attributes = {})
          @namespace = attributes[:namespace] || attributes["namespace"]
          @includes = Array(attributes[:includes] || attributes["includes"])
          @tables = Array(attributes[:tables] || attributes["tables"])
          @structs = Array(attributes[:structs] || attributes["structs"])
          @enums = Array(attributes[:enums] || attributes["enums"])
          @unions = Array(attributes[:unions] || attributes["unions"])
          @root_type = attributes[:root_type] || attributes["root_type"]
          @file_identifier = attributes[:file_identifier] || attributes["file_identifier"]
          @file_extension = attributes[:file_extension] || attributes["file_extension"]
          @attributes = Array(attributes[:attributes] || attributes["attributes"])
        end

        # Queries
        def find_table(name)
          tables.find { |t| t.name == name }
        end

        def find_struct(name)
          structs.find { |s| s.name == name }
        end

        def find_enum(name)
          enums.find { |e| e.name == name }
        end

        def find_union(name)
          unions.find { |u| u.name == name }
        end

        def find_type(name)
          find_table(name) || find_struct(name) || find_enum(name) || find_union(name)
        end

        def table_names
          tables.map(&:name)
        end

        def struct_names
          structs.map(&:name)
        end

        def enum_names
          enums.map(&:name)
        end

        def union_names
          unions.map(&:name)
        end

        # Validation
        def valid?
          validate!
          true
        rescue ValidationError
          false
        end

        def validate!
          raise ValidationError, "Root type required" unless root_type

          unless find_table(root_type)
            raise ValidationError,
                  "Root type '#{root_type}' not found"
          end

          tables.each(&:validate!)
          structs.each(&:validate!)
          enums.each(&:validate!)
          unions.each(&:validate!)

          true
        end

        def to_h
          {
            namespace: namespace,
            includes: includes,
            tables: tables.map(&:to_h),
            structs: structs.map(&:to_h),
            enums: enums.map(&:to_h),
            unions: unions.map(&:to_h),
            root_type: root_type,
            file_identifier: file_identifier,
            file_extension: file_extension,
            attributes: attributes,
          }
        end
      end
    end
  end
end
