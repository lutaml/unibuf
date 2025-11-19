# frozen_string_literal: true

require_relative "segment_builder"
require_relative "pointer_encoder"
require_relative "struct_writer"
require_relative "list_writer"

module Unibuf
  module Serializers
    module Capnproto
      # Serializer for Cap'n Proto binary format
      # Coordinates segment building, pointer encoding, and data writing
      class BinarySerializer
        attr_reader :schema, :segment_builder

        # Initialize with schema
        # @param schema [Models::Capnproto::Schema] Cap'n Proto schema
        def initialize(schema)
          @schema = schema
          @segment_builder = SegmentBuilder.new
        end

        # Serialize data to binary format
        # @param data [Hash] Data to serialize
        # @param root_type [String, nil] Root struct type name
        # @return [String] Binary data
        def serialize(data, root_type: nil)
          # Determine root type from schema if not provided
          root_type ||= @schema.structs.first&.name
          raise SerializationError, "No root type specified" unless root_type

          struct_def = @schema.find_struct(root_type)
          unless struct_def
            raise SerializationError,
                  "Struct type not found: #{root_type}"
          end

          # Allocate root pointer (1 word at position 0)
          @segment_builder.allocate(1)

          # Write root struct and get its location
          root_location = write_struct(data, struct_def)

          # Write root pointer at position 0
          # Root pointer points to position 1 (offset = 0 from position 1)
          pointer = PointerEncoder.encode_struct(
            0, # offset from pointer position (1) to struct (1)
            root_location[:data_words],
            root_location[:pointer_words],
          )
          @segment_builder.write_word(0, 0, pointer)

          # Build final binary
          @segment_builder.build
        end

        private

        # Write a struct
        # @param data [Hash] Struct data
        # @param struct_def [Models::Capnproto::StructDefinition] Struct definition
        # @return [Hash] Location info
        def write_struct(data, struct_def)
          # Count data and pointer words needed
          data_words = calculate_data_words(struct_def)
          pointer_words = calculate_pointer_words(struct_def)

          # Allocate space for struct
          segment_id, word_offset = @segment_builder.allocate(data_words + pointer_words)

          # Create struct writer
          struct_writer = StructWriter.new(
            @segment_builder,
            segment_id,
            word_offset,
            data_words,
            pointer_words,
          )

          # Write each field
          struct_def.fields.each do |field|
            value = data[field.name.to_sym] || data[field.name]
            next unless value

            write_field(struct_writer, field, value, struct_def)
          end

          {
            segment_id: segment_id,
            word_offset: word_offset,
            data_words: data_words,
            pointer_words: pointer_words,
          }
        end

        # Write a field
        def write_field(struct_writer, field, value, struct_def)
          if field.primitive_type?
            write_primitive_field(struct_writer, field, value)
          elsif field.list_type?
            write_list_field(struct_writer, field, value, struct_def)
          elsif text_or_data_type?(field)
            write_text_or_data_field(struct_writer, field, value, struct_def)
          elsif field.user_type?
            write_user_type_field(struct_writer, field, value, struct_def)
          end
        end

        # Write a primitive field
        def write_primitive_field(struct_writer, field, value)
          ordinal = field.ordinal
          type = field.type

          case type
          when "Bool"
            struct_writer.write_bool(ordinal / 64, ordinal % 64, value)
          when "Int8"
            struct_writer.write_int8(ordinal / 8, ordinal % 8, value)
          when "UInt8"
            struct_writer.write_uint8(ordinal / 8, ordinal % 8, value)
          when "Int16"
            struct_writer.write_int16(ordinal / 4, ordinal % 4, value)
          when "UInt16"
            struct_writer.write_uint16(ordinal / 4, ordinal % 4, value)
          when "Int32"
            struct_writer.write_int32(ordinal / 2, ordinal % 2, value)
          when "UInt32"
            struct_writer.write_uint32(ordinal / 2, ordinal % 2, value)
          when "Int64"
            struct_writer.write_int64(ordinal, value)
          when "UInt64"
            struct_writer.write_uint64(ordinal, value)
          when "Float32"
            struct_writer.write_float32(ordinal / 2, ordinal % 2, value)
          when "Float64"
            struct_writer.write_float64(ordinal, value)
          end
        end

        # Write a list field
        def write_list_field(struct_writer, field, value, struct_def)
          return if value.nil? || value.empty?

          element_type = field.element_type

          # Handle Text specially
          if element_type == "Text"
            write_text_field(struct_writer, field, value, struct_def)
            return
          end

          # Determine element size
          element_size = PointerEncoder.element_size_for_type(element_type)
          element_count = value.length

          # Allocate space for list
          words_needed = calculate_list_words(element_size, element_count)
          segment_id, word_offset = @segment_builder.allocate(words_needed)

          # Create list writer
          list_writer = ListWriter.new(
            @segment_builder,
            segment_id,
            word_offset,
            element_size,
            element_count,
          )

          # Write elements
          value.each_with_index do |elem, i|
            if primitive_type?(element_type)
              type_symbol = type_to_symbol(element_type)
              list_writer.write_primitive(i, elem, type_symbol)
            else
              # Handle struct elements (more complex, simplified for now)
              # Would need to recursively write structs
            end
          end

          # Get pointer index for this field
          pointer_index = get_pointer_index(field, struct_def)

          # Calculate offset from pointer position to list
          pointer_pos = struct_writer.pointer_position(pointer_index)
          offset = word_offset - pointer_pos - 1

          # Write list pointer
          pointer = PointerEncoder.encode_list(offset, element_size,
                                               element_count)
          struct_writer.write_pointer(pointer_index, pointer)
        end

        # Write Text or Data field
        def write_text_or_data_field(struct_writer, field, value, struct_def)
          if field.type == "Text"
            write_text_field(struct_writer, field, value, struct_def)
          else
            # Data field - similar to text but no encoding
            write_data_field(struct_writer, field, value, struct_def)
          end
        end

        # Write data field
        def write_data_field(struct_writer, field, value, struct_def)
          # Data is a byte list
          element_count = value.bytesize

          # Calculate words needed
          words_needed = (element_count + 7) / 8
          segment_id, word_offset = @segment_builder.allocate(words_needed)

          # Create list writer
          list_writer = ListWriter.new(
            @segment_builder,
            segment_id,
            word_offset,
            PointerEncoder::ELEMENT_SIZE_BYTE,
            element_count,
          )

          # Write data
          list_writer.write_data(value)

          # Get pointer index for this field
          pointer_index = get_pointer_index(field, struct_def)

          # Calculate offset and write pointer
          pointer_pos = struct_writer.pointer_position(pointer_index)
          offset = word_offset - pointer_pos - 1

          pointer = PointerEncoder.encode_list(offset,
                                               PointerEncoder::ELEMENT_SIZE_BYTE, element_count)
          struct_writer.write_pointer(pointer_index, pointer)
        end

        # Write text field
        def write_text_field(struct_writer, field, value, struct_def)
          # Text is a byte list with null terminator
          bytes = value.bytes + [0]
          element_count = bytes.length

          # Calculate words needed
          words_needed = (element_count + 7) / 8
          segment_id, word_offset = @segment_builder.allocate(words_needed)

          # Create list writer
          list_writer = ListWriter.new(
            @segment_builder,
            segment_id,
            word_offset,
            PointerEncoder::ELEMENT_SIZE_BYTE,
            element_count,
          )

          # Write text
          list_writer.write_text(value)

          # Get pointer index for this field
          pointer_index = get_pointer_index(field, struct_def)

          # Calculate offset and write pointer
          pointer_pos = struct_writer.pointer_position(pointer_index)
          offset = word_offset - pointer_pos - 1

          pointer = PointerEncoder.encode_list(offset,
                                               PointerEncoder::ELEMENT_SIZE_BYTE, element_count)
          struct_writer.write_pointer(pointer_index, pointer)
        end

        # Write user-defined type field
        def write_user_type_field(struct_writer, field, value, struct_def)
          # Check if it's an enum
          enum_def = @schema.find_enum(field.type)
          if enum_def
            # Enums are stored as UInt16
            ordinal_value = if value.is_a?(String) || value.is_a?(Symbol)
                              enum_def.values[value.to_s]
                            else
                              value
                            end
            struct_writer.write_uint16(field.ordinal / 4, field.ordinal % 4,
                                       ordinal_value || 0)
          else
            # It's a struct - write recursively
            nested_struct_def = @schema.find_struct(field.type)
            return unless nested_struct_def

            nested_location = write_struct(value, nested_struct_def)

            # Get pointer index for this field
            pointer_index = get_pointer_index(field, struct_def)

            # Calculate offset and write pointer
            pointer_pos = struct_writer.pointer_position(pointer_index)
            offset = nested_location[:word_offset] - pointer_pos - 1

            pointer = PointerEncoder.encode_struct(
              offset,
              nested_location[:data_words],
              nested_location[:pointer_words],
            )
            struct_writer.write_pointer(pointer_index, pointer)
          end
        end

        # Get pointer index for a field
        # Count non-primitive fields before this one
        def get_pointer_index(field, struct_def)
          struct_def.fields.take_while do |f|
            f != field
          end.count { |f| !f.primitive_type? }
        end

        # Helper methods
        def calculate_data_words(struct_def)
          # In Cap'n Proto, we need to count actual data words based on field types
          # Group fields by their size and pack them efficiently
          max_word = 0

          struct_def.fields.each do |field|
            next unless field.primitive_type?

            word_index = case field.type
                         when "Bool"
                           field.ordinal / 64  # 64 bools per word
                         when "Int8", "UInt8"
                           field.ordinal / 8   # 8 bytes per word
                         when "Int16", "UInt16"
                           field.ordinal / 4   # 4 shorts per word
                         when "Int32", "UInt32", "Float32"
                           field.ordinal / 2   # 2 ints per word
                         when "Int64", "UInt64", "Float64"
                           field.ordinal       # 1 long per word
                         else
                           0
                         end

            max_word = [max_word, word_index].max
          end

          max_word + 1
        end

        def calculate_pointer_words(struct_def)
          # Pointer fields use separate ordinals
          # Count fields that are NOT primitives
          pointer_fields = struct_def.fields.reject(&:primitive_type?)
          return 0 if pointer_fields.empty?

          # Get max pointer ordinal
          max_pointer_ordinal = pointer_fields.map(&:ordinal).max
          max_pointer_ordinal + 1
        end

        def calculate_list_words(element_size, count)
          case element_size
          when PointerEncoder::ELEMENT_SIZE_VOID
            0
          when PointerEncoder::ELEMENT_SIZE_BIT
            (count + 63) / 64
          when PointerEncoder::ELEMENT_SIZE_BYTE
            (count + 7) / 8
          when PointerEncoder::ELEMENT_SIZE_TWO_BYTES
            (count + 3) / 4
          when PointerEncoder::ELEMENT_SIZE_FOUR_BYTES
            (count + 1) / 2
          when PointerEncoder::ELEMENT_SIZE_EIGHT_BYTES, PointerEncoder::ELEMENT_SIZE_POINTER
            count
          else
            count # Inline composite
          end
        end

        def primitive_type?(type)
          Models::Capnproto::FieldDefinition::PRIMITIVE_TYPES.include?(type)
        end

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

        # Check if field is Text or Data type
        def text_or_data_type?(field)
          ["Text", "Data"].include?(field.type)
        end
      end
    end
  end
end
