# frozen_string_literal: true

require_relative "../../models/schema"
require_relative "../../models/message_definition"
require_relative "../../models/field_definition"
require_relative "../../models/enum_definition"

module Unibuf
  module Parsers
    module Proto3
      # Processor to transform Proto3 AST to Schema models
      class Processor
        class << self
          def process(ast)
            return Models::Schema.new unless ast

            elements = Array(ast)

            attributes = {
              syntax: extract_syntax(elements),
              package: extract_package(elements),
              imports: extract_imports(elements),
              messages: extract_messages(elements),
              enums: extract_enums(elements),
            }

            Models::Schema.new(attributes)
          end

          private

          def extract_syntax(elements)
            syntax_element = elements.find { |el| el.key?(:syntax) }
            return "proto3" unless syntax_element

            syntax_element[:syntax][:syntax_version][:string].to_s
          end

          def extract_package(elements)
            pkg_element = elements.find { |el| el.key?(:package) }
            return nil unless pkg_element

            # Package is array of identifiers: [{:package=>{:identifier=>"google"}}, {:identifier=>"fonts"}]
            pkg_parts = Array(pkg_element[:package])
            names = pkg_parts.filter_map do |part|
              if part[:package]
                part[:package][:identifier].to_s
              elsif part[:identifier]
                part[:identifier].to_s
              end
            end

            names.join(".")
          end

          def extract_imports(elements)
            elements.select { |el| el.key?(:import) }.map do |el|
              el[:import][:import][:string].to_s
            end
          end

          def extract_messages(elements)
            elements.select { |el| el.key?(:message) }.map do |el|
              process_message(el[:message])
            end
          end

          def extract_enums(elements)
            elements.select { |el| el.key?(:enum) }.map do |el|
              process_enum(el[:enum])
            end
          end

          def process_message(msg_data)
            name = msg_data[:message_name][:identifier].to_s
            body = msg_data[:body]

            fields = extract_fields(body)
            nested_messages = extract_nested_messages(body)
            nested_enums = extract_nested_enums(body)

            Models::MessageDefinition.new(
              name: name,
              fields: fields,
              nested_messages: nested_messages,
              nested_enums: nested_enums,
            )
          end

          def extract_fields(body)
            return [] unless body

            result = []

            # Extract regular fields
            Array(body).each do |el|
              if el.respond_to?(:key?) && el.key?(:field)
                result << process_field(el[:field])
              elsif el.respond_to?(:key?) && el.key?(:map_field)
                result << process_map_field(el[:map_field])
              end
            end

            result
          end

          def extract_nested_messages(body)
            return [] unless body

            Array(body).select do |el|
              el.respond_to?(:key?) && el.key?(:nested_message)
            end.map do |el|
              process_message(el[:nested_message])
            end
          end

          def extract_nested_enums(body)
            return [] unless body

            Array(body).select do |el|
              el.respond_to?(:key?) && el.key?(:enum)
            end.map do |el|
              process_enum(el[:enum])
            end
          end

          def process_field(field_data)
            type_info = field_data[:type]
            type = if type_info[:scalar_type]
                     type_info[:scalar_type].to_s
                   else
                     type_info[:message_type][:identifier].to_s
                   end

            Models::FieldDefinition.new(
              name: field_data[:name][:identifier].to_s,
              type: type,
              number: field_data[:field_number][:number].to_s.to_i,
              label: field_data[:repeated] ? "repeated" : nil,
            )
          end

          def process_map_field(map_data)
            key_type_info = map_data[:key_type]
            key_type = if key_type_info[:scalar_type]
                         key_type_info[:scalar_type].to_s
                       else
                         key_type_info[:message_type][:identifier].to_s
                       end

            value_type_info = map_data[:value_type]
            value_type = if value_type_info[:scalar_type]
                           value_type_info[:scalar_type].to_s
                         else
                           value_type_info[:message_type][:identifier].to_s
                         end

            Models::FieldDefinition.new(
              name: map_data[:name][:identifier].to_s,
              type: "map",
              number: map_data[:field_number][:number].to_s.to_i,
              key_type: key_type,
              value_type: value_type,
            )
          end

          def process_enum(enum_data)
            name = enum_data[:enum_name][:identifier].to_s
            values = {}

            Array(enum_data[:values]).each do |val|
              next unless val.respond_to?(:key?) && val.key?(:name)

              val_name = val[:name][:identifier].to_s
              val_num = val[:value][:number].to_s.to_i
              values[val_name] = val_num
            end

            Models::EnumDefinition.new(
              name: name,
              values: values,
            )
          end
        end
      end
    end
  end
end
