# frozen_string_literal: true

require_relative "../../models/capnproto/schema"
require_relative "../../models/capnproto/struct_definition"
require_relative "../../models/capnproto/field_definition"
require_relative "../../models/capnproto/enum_definition"
require_relative "../../models/capnproto/interface_definition"
require_relative "../../models/capnproto/method_definition"
require_relative "../../models/capnproto/union_definition"

module Unibuf
  module Parsers
    module Capnproto
      # Processor to transform Cap'n Proto AST to Schema models
      class Processor
        class << self
          def process(ast)
            return Models::Capnproto::Schema.new unless ast

            elements = Array(ast)

            attributes = {
              file_id: extract_file_id(elements),
              usings: extract_usings(elements),
              structs: extract_structs(elements),
              enums: extract_enums(elements),
              interfaces: extract_interfaces(elements),
              constants: extract_constants(elements),
            }

            Models::Capnproto::Schema.new(attributes)
          end

          private

          def extract_file_id(elements)
            file_id_element = elements.find { |el| el.key?(:file_id) }
            return nil unless file_id_element

            file_id_element[:file_id][:number].to_s
          end

          def extract_usings(elements)
            elements.select { |el| el.key?(:using) }.map do |el|
              {
                alias: el[:using][:alias][:identifier].to_s,
                import_path: el[:using][:import_path][:string].to_s,
              }
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

          def extract_interfaces(elements)
            elements.select { |el| el.key?(:interface) }.map do |el|
              process_interface(el[:interface])
            end
          end

          def extract_constants(elements)
            elements.select { |el| el.key?(:const) }.map do |el|
              process_const(el[:const])
            end
          end

          def process_struct(struct_data)
            name = struct_data[:struct_name][:identifier].to_s
            body = struct_data[:body]
            annotations = extract_annotations(struct_data[:annotation])

            fields = extract_struct_fields(body)
            unions = extract_unions(body)
            groups = extract_groups(body)
            nested_structs = extract_nested_structs(body)
            nested_enums = extract_nested_enums(body)
            nested_interfaces = extract_nested_interfaces(body)

            Models::Capnproto::StructDefinition.new(
              name: name,
              fields: fields,
              unions: unions,
              groups: groups,
              nested_structs: nested_structs,
              nested_enums: nested_enums,
              nested_interfaces: nested_interfaces,
              annotations: annotations,
            )
          end

          def extract_struct_fields(body)
            return [] unless body

            Array(body).select do |el|
              el.respond_to?(:key?) && el.key?(:field)
            end.map do |el|
              process_field(el[:field])
            end
          end

          def extract_unions(body)
            return [] unless body

            Array(body).select do |el|
              el.respond_to?(:key?) && el.key?(:union)
            end.map do |el|
              process_union(el[:union])
            end
          end

          def extract_groups(body)
            return [] unless body

            Array(body).select do |el|
              el.respond_to?(:key?) && el.key?(:group)
            end.map do |el|
              process_group(el[:group])
            end
          end

          def extract_nested_structs(body)
            return [] unless body

            Array(body).select do |el|
              el.respond_to?(:key?) && el.key?(:nested_struct)
            end.map do |el|
              process_struct(el[:nested_struct])
            end
          end

          def extract_nested_enums(body)
            return [] unless body

            Array(body).select do |el|
              el.respond_to?(:key?) && el.key?(:nested_enum)
            end.map do |el|
              process_enum(el[:nested_enum])
            end
          end

          def extract_nested_interfaces(body)
            return [] unless body

            Array(body).select do |el|
              el.respond_to?(:key?) && el.key?(:nested_interface)
            end.map do |el|
              process_interface(el[:nested_interface])
            end
          end

          def process_field(field_data)
            name = field_data[:name][:identifier].to_s
            ordinal = field_data[:ordinal][:number].to_s.to_i
            type = process_field_type(field_data[:type])
            default_value = process_default_value(field_data[:default])

            Models::Capnproto::FieldDefinition.new(
              name: name,
              ordinal: ordinal,
              type: type,
              default_value: default_value,
            )
          end

          def process_field_type(type_data)
            if type_data[:generic]
              # Generic type: List(T)
              {
                generic: "List",
                element_type: process_field_type(type_data[:generic][:element_type]),
              }
            elsif type_data[:primitive_type]
              type_data[:primitive_type].to_s
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
            end
          end

          def process_union(union_data)
            fields = extract_struct_fields(union_data[:fields])

            Models::Capnproto::UnionDefinition.new(
              fields: fields,
            )
          end

          def process_group(group_data)
            name = group_data[:name][:identifier].to_s
            ordinal = group_data[:ordinal][:number].to_s.to_i
            fields = extract_struct_fields(group_data[:fields])

            {
              name: name,
              ordinal: ordinal,
              fields: fields.map(&:to_h),
            }
          end

          def process_enum(enum_data)
            name = enum_data[:enum_name][:identifier].to_s
            annotations = extract_annotations(enum_data[:annotation])
            values = {}

            Array(enum_data[:values]).each do |val_el|
              next unless val_el.respond_to?(:key?)

              val_name = val_el[:name][:identifier].to_s
              val_ordinal = val_el[:ordinal][:number].to_s.to_i

              values[val_name] = val_ordinal
            end

            Models::Capnproto::EnumDefinition.new(
              name: name,
              values: values,
              annotations: annotations,
            )
          end

          def process_interface(interface_data)
            name = interface_data[:interface_name][:identifier].to_s
            annotations = extract_annotations(interface_data[:annotation])
            body = interface_data[:body]

            methods = extract_methods(body)

            Models::Capnproto::InterfaceDefinition.new(
              name: name,
              methods: methods,
              annotations: annotations,
            )
          end

          def extract_methods(body)
            return [] unless body

            Array(body).select do |el|
              el.respond_to?(:key?) && el.key?(:method)
            end.map do |el|
              process_method(el[:method])
            end
          end

          def process_method(method_data)
            name = method_data[:name][:identifier].to_s
            ordinal = method_data[:ordinal][:number].to_s.to_i
            params = extract_params(method_data[:params])
            results = extract_params(method_data[:results])

            Models::Capnproto::MethodDefinition.new(
              name: name,
              ordinal: ordinal,
              params: params,
              results: results,
            )
          end

          def extract_params(params_data)
            return [] unless params_data

            Array(params_data).select do |el|
              el.respond_to?(:key?) && el.key?(:param)
            end.map do |el|
              param = el[:param]
              {
                name: param[:name][:identifier].to_s,
                type: process_field_type(param[:type]),
              }
            end
          end

          def process_const(const_data)
            {
              name: const_data[:name][:identifier].to_s,
              type: process_field_type(const_data[:type]),
              value: process_const_value(const_data[:value]),
            }
          end

          def process_const_value(value_data)
            if value_data[:number]
              val = value_data[:number].to_s
              val.include?(".") ? val.to_f : val.to_i
            elsif value_data[:bool]
              value_data[:bool].to_s == "true"
            elsif value_data[:string]
              value_data[:string].to_s
            elsif value_data[:ref]
              value_data[:ref][:identifier].to_s
            end
          end

          def extract_annotations(annotation_data)
            return [] unless annotation_data

            Array(annotation_data).map do |ann|
              name = ann[:annotation][:identifier].to_s
              value = if ann[:value]
                        process_annotation_value(ann[:value])
                      else
                        true
                      end

              { name: name, value: value }
            end
          end

          def process_annotation_value(value_data)
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
        end
      end
    end
  end
end
