# frozen_string_literal: true

require_relative "segment_reader"
require_relative "pointer_decoder"
require_relative "struct_reader"
require_relative "list_reader"

module Unibuf
  module Parsers
    module Capnproto
      # Parser for Cap'n Proto binary format
      # Coordinates segment reading, pointer following, and data extraction
      class BinaryParser
        attr_reader :schema, :segment_reader

        # Initialize with schema
        # @param schema [Models::Capnproto::Schema] Cap'n Proto schema
        def initialize(schema)
          @schema = schema
          @segment_reader = nil
        end

        # Parse binary data
        # @param data [String] Binary data
        # @param root_type [String, nil] Root struct type name
        # @return [Hash] Parsed data
        def parse(data, root_type: nil)
          @segment_reader = SegmentReader.new(data)

          # Root object is at segment 0, word 0
          # First word is a pointer to the root struct
          root_pointer_word = @segment_reader.read_word(0, 0)
          root_pointer = PointerDecoder.decode(root_pointer_word)

          unless root_pointer[:type] == :struct
            raise ParseError,
                  "Invalid root pointer"
          end

          # Follow pointer to root struct
          root_struct_offset = 1 + root_pointer[:offset]
          root_struct = StructReader.new(
            @segment_reader,
            0,
            root_struct_offset,
            root_pointer[:data_words],
            root_pointer[:pointer_words],
          )

          # Determine root type from schema if not provided
          root_type ||= @schema.structs.first&.name
          raise ParseError, "No root type specified" unless root_type

          struct_def = @schema.find_struct(root_type)
          unless struct_def
            raise ParseError,
                  "Struct type not found: #{root_type}"
          end

          parse_struct(root_struct, struct_def)
        end

        private

        # Parse a struct according to its definition
        # @param struct_reader [StructReader] Struct reader
        # @param struct_def [Models::Capnproto::StructDefinition] Struct definition
        # @return [Hash] Parsed data
        def parse_struct(struct_reader, struct_def)
          result = {}

          struct_def.fields.each do |field|
            result[field.name.to_sym] =
              parse_field(struct_reader, field, struct_def)
          end

          result
        end

        # Parse a field
        # @param struct_reader [StructReader] Struct reader
        # @param field [Models::Capnproto::FieldDefinition] Field definition
        # @param struct_def [Models::Capnproto::StructDefinition] Parent struct definition
        # @return [Object] Field value
        def parse_field(struct_reader, field, struct_def)
          if field.primitive_type?
            parse_primitive_field(struct_reader, field)
          elsif field.list_type?
            parse_list_field(struct_reader, field, struct_def)
          elsif text_or_data_type?(field)
            parse_text_or_data_field(struct_reader, field, struct_def)
          elsif field.user_type?
            parse_user_type_field(struct_reader, field, struct_def)
          end
        end

        # Parse a primitive field
        def parse_primitive_field(struct_reader, field)
          ordinal = field.ordinal
          type = field.type

          # Calculate word and offset based on type
          case type
          when "Bool"
            struct_reader.read_bool(ordinal / 64, ordinal % 64)
          when "Int8"
            struct_reader.read_int8(ordinal / 8, ordinal % 8)
          when "UInt8"
            struct_reader.read_uint8(ordinal / 8, ordinal % 8)
          when "Int16"
            struct_reader.read_int16(ordinal / 4, ordinal % 4)
          when "UInt16"
            struct_reader.read_uint16(ordinal / 4, ordinal % 4)
          when "Int32"
            struct_reader.read_int32(ordinal / 2, ordinal % 2)
          when "UInt32"
            struct_reader.read_uint32(ordinal / 2, ordinal % 2)
          when "Int64"
            struct_reader.read_int64(ordinal)
          when "UInt64"
            struct_reader.read_uint64(ordinal)
          when "Float32"
            struct_reader.read_float32(ordinal / 2, ordinal % 2)
          when "Float64"
            struct_reader.read_float64(ordinal)
          when "Void"
            nil
          else
            field.default_value
          end
        end

        # Parse a list field
        def parse_list_field(struct_reader, field, struct_def)
          # Get pointer index - count non-primitive fields before this one
          pointer_index = get_pointer_index(field, struct_def)

          target = struct_reader.follow_pointer(pointer_index)
          return nil unless target && target[:type] == :list

          list_reader = ListReader.new(
            @segment_reader,
            target[:segment_id],
            target[:word_offset],
            target[:element_size],
            target[:element_count],
          )

          element_type = field.element_type

          # Check if element is Text or Data
          if element_type == "Text"
            return list_reader.read_text
          elsif element_type == "Data"
            return list_reader.read_data
          end

          # Parse list elements
          (0...list_reader.length).map do |i|
            if primitive_type?(element_type)
              type_symbol = type_to_symbol(element_type)
              list_reader.read_primitive(i, type_symbol)
            else
              # Struct element
              element_struct_def = @schema.find_struct(element_type)
              if element_struct_def
                element_struct = list_reader.read_struct(i)
                parse_struct(element_struct, element_struct_def)
              end
            end
          end
        end

        # Parse a user-defined type field (struct, enum, etc.)
        def parse_user_type_field(struct_reader, field, struct_def)
          # Check if it's an enum
          enum_def = @schema.find_enum(field.type)
          if enum_def
            # Enums are stored as UInt16 in data section
            value = struct_reader.read_uint16(field.ordinal / 4,
                                              field.ordinal % 4)
            # Find enum name by value
            enum_def.find_name_by_ordinal(value) || value
          else
            # It's a struct - use pointer index
            pointer_index = get_pointer_index(field, struct_def)

            target = struct_reader.follow_pointer(pointer_index)
            return nil unless target && target[:type] == :struct

            nested_struct = StructReader.new(
              @segment_reader,
              target[:segment_id],
              target[:word_offset],
              target[:data_words],
              target[:pointer_words],
            )

            nested_struct_def = @schema.find_struct(field.type)
            return nil unless nested_struct_def

            parse_struct(nested_struct, nested_struct_def)
          end
        end

        # Parse Text or Data field (special pointer types)
        def parse_text_or_data_field(struct_reader, field, struct_def)
          # Get pointer index
          pointer_index = get_pointer_index(field, struct_def)

          target = struct_reader.follow_pointer(pointer_index)
          return nil unless target && target[:type] == :list

          list_reader = ListReader.new(
            @segment_reader,
            target[:segment_id],
            target[:word_offset],
            target[:element_size],
            target[:element_count],
          )

          if field.type == "Text"
            list_reader.read_text
          else
            list_reader.read_data
          end
        end

        # Get pointer index for a field
        # Count non-primitive fields before this one
        def get_pointer_index(field, struct_def)
          struct_def.fields.take_while do |f|
            f != field
          end.count { |f| !f.primitive_type? }
        end

        # Check if field is Text or Data type
        def text_or_data_type?(field)
          ["Text", "Data"].include?(field.type)
        end

        # Check if type is primitive
        def primitive_type?(type)
          Models::Capnproto::FieldDefinition::PRIMITIVE_TYPES.include?(type)
        end

        # Convert type string to symbol for list reading
        def type_to_symbol(type)
          case type
          when "Int8" then :int8
          when "UInt8" then :uint8
          when "Int16" then :int16
          when "UInt16" then :uint16
          when "Int32" then :int32
          when "UInt32" then :uint32
          when "Int64" then :int64
          when "UInt64" then :uint64
          when "Float32" then :float32
          when "Float64" then :float64
          when "Bool" then :bool
          else :uint64
          end
        end
      end
    end
  end
end
