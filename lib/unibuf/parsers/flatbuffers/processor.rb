# frozen_string_literal: true

require_relative "../../models/flatbuffers/schema"
require_relative "../../models/flatbuffers/table_definition"
require_relative "../../models/flatbuffers/struct_definition"
require_relative "../../models/flatbuffers/field_definition"
require_relative "../../models/flatbuffers/enum_definition"
require_relative "../../models/flatbuffers/union_definition"

module Unibuf
  module Parsers
    module Flatbuffers
      # Processor to transform FlatBuffers AST to Schema models
      class Processor
        class << self
          def process(ast)
            return Models::Flatbuffers::Schema.new unless ast

            elements = Array(ast)

            attributes = {
              namespace: extract_namespace(elements),
              includes: extract_includes(elements),
              tables: extract_tables(elements),
              structs: extract_structs(elements),
              enums: extract_enums(elements),
              unions: extract_unions(elements),
              root_type: extract_root_type(elements),
              file_identifier: extract_file_identifier(elements),
              file_extension: extract_file_extension(elements),
              attributes: extract_attributes(elements),
            }

            Models::Flatbuffers::Schema.new(attributes)
          end

          private

          def extract_namespace(elements)
            ns_element = elements.find { |el| el.key?(:namespace) }
            return nil unless ns_element

            # Namespace is array of identifiers
            ns_parts = Array(ns_element[:namespace])
            names = ns_parts.filter_map do |part|
              if part[:namespace]
                part[:namespace][:identifier].to_s
              elsif part[:identifier]
                part[:identifier].to_s
              end
            end

            names.join(".")
          end

          def extract_includes(elements)
            elements.select { |el| el.key?(:include) }.map do |el|
              el[:include][:include][:string].to_s
            end
          end

          def extract_tables(elements)
            elements.select { |el| el.key?(:table) }.map do |el|
              process_table(el[:table])
            end
          end

          def extract_structs(elements)
            elements.select { |el| el.key?(:struct) }.map do |el|
              process_struct(el[:struct])
            end
          end

          def extract_enums(elements)
            elements.select { |el| el.key?(:enum) }.map do |el|
              process_enum(el[:enum])
            end
          end

          def extract_unions(elements)
            elements.select { |el| el.key?(:union) }.map do |el|
              process_union(el[:union])
            end
          end

          def extract_root_type(elements)
            root_element = elements.find { |el| el.key?(:root_type) }
            return nil unless root_element

            root_element[:root_type][:root_type][:identifier].to_s
          end

          def extract_file_identifier(elements)
            fi_element = elements.find { |el| el.key?(:file_identifier) }
            return nil unless fi_element

            fi_element[:file_identifier][:file_identifier][:string].to_s
          end

          def extract_file_extension(elements)
            fe_element = elements.find { |el| el.key?(:file_extension) }
            return nil unless fe_element

            fe_element[:file_extension][:file_extension][:string].to_s
          end

          def extract_attributes(elements)
            elements.select { |el| el.key?(:attribute_decl) }.map do |el|
              el[:attribute_decl][:attribute][:string].to_s
            end
          end

          def process_table(table_data)
            name = table_data[:table_name][:identifier].to_s
            body = table_data[:body]
            metadata = process_metadata(table_data[:metadata])

            fields = extract_table_fields(body)

            Models::Flatbuffers::TableDefinition.new(
              name: name,
              fields: fields,
              metadata: metadata,
            )
          end

          def process_struct(struct_data)
            name = struct_data[:struct_name][:identifier].to_s
            body = struct_data[:body]
            metadata = process_metadata(struct_data[:metadata])

            fields = extract_struct_fields(body)

            Models::Flatbuffers::StructDefinition.new(
              name: name,
              fields: fields,
              metadata: metadata,
            )
          end

          def extract_table_fields(body)
            return [] unless body

            Array(body).select do |el|
              el.respond_to?(:key?) && el.key?(:field)
            end.map do |el|
              process_field(el[:field])
            end
          end

          def extract_struct_fields(body)
            return [] unless body

            Array(body).select do |el|
              el.respond_to?(:key?) && el.key?(:field)
            end.map do |el|
              process_field(el[:field])
            end
          end

          def process_field(field_data)
            name = field_data[:name][:identifier].to_s
            type = process_field_type(field_data[:type])
            default_value = process_default_value(field_data[:default])
            metadata = process_metadata(field_data[:metadata])

            Models::Flatbuffers::FieldDefinition.new(
              name: name,
              type: type,
              default_value: default_value,
              metadata: metadata,
            )
          end

          def process_field_type(type_data)
            if type_data[:vector]
              # Vector type: [element_type]
              element_type = if type_data[:vector][:scalar_type]
                               type_data[:vector][:scalar_type].to_s
                             else
                               type_data[:vector][:user_type][:identifier].to_s
                             end
              { vector: element_type }
            elsif type_data[:scalar_type]
              type_data[:scalar_type].to_s
            else
              type_data[:user_type][:identifier].to_s
            end
          end

          def process_default_value(default_data)
            return nil unless default_data

            if default_data[:number]
              val = default_data[:number].to_s
              val.include?(".") ? val.to_f : val.to_i
            elsif default_data[:bool]
              default_data[:bool].to_s == "true"
            elsif default_data[:string]
              default_data[:string].to_s
            elsif default_data[:enum_value]
              default_data[:enum_value][:identifier].to_s
            end
          end

          def process_metadata(metadata_data)
            return {} unless metadata_data

            result = {}
            attrs = Array(metadata_data).select { |el| el.key?(:attr) }

            attrs.each do |attr_el|
              attr = attr_el[:attr]
              name = attr[:name][:identifier].to_s.to_sym

              value = if attr[:value]
                        process_metadata_value(attr[:value])
                      else
                        true
                      end

              result[name] = value
            end

            result
          end

          def process_metadata_value(value_data)
            if value_data[:number]
              val = value_data[:number].to_s
              val.include?(".") ? val.to_f : val.to_i
            elsif value_data[:bool]
              value_data[:bool].to_s == "true"
            elsif value_data[:string]
              value_data[:string].to_s
            elsif value_data[:identifier]
              value_data[:identifier].to_s
            else
              value_data.to_s
            end
          end

          def process_enum(enum_data)
            name = enum_data[:enum_name][:identifier].to_s
            type = if enum_data[:enum_type]
                     enum_data[:enum_type][:enum_type].to_s
                   else
                     "int"
                   end
            metadata = process_metadata(enum_data[:metadata])
            values = {}

            last_value = -1
            Array(enum_data[:values]).each do |val_el|
              next unless val_el.respond_to?(:key?) && val_el.key?(:value)

              val = val_el[:value]
              val_name = val[:name][:identifier].to_s

              val_num = if val[:value]
                          val[:value][:number].to_s.to_i
                        else
                          last_value + 1
                        end

              values[val_name] = val_num
              last_value = val_num
            end

            Models::Flatbuffers::EnumDefinition.new(
              name: name,
              type: type,
              values: values,
              metadata: metadata,
            )
          end

          def process_union(union_data)
            name = union_data[:union_name][:identifier].to_s
            metadata = process_metadata(union_data[:metadata])
            types = []

            Array(union_data[:types]).each do |type_el|
              next unless type_el.respond_to?(:key?) && type_el.key?(:type)

              types << type_el[:type][:type][:identifier].to_s
            end

            Models::Flatbuffers::UnionDefinition.new(
              name: name,
              types: types,
              metadata: metadata,
            )
          end
        end
      end
    end
  end
end