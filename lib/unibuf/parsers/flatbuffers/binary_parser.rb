# frozen_string_literal: true

require "stringio"

module Unibuf
  module Parsers
    module Flatbuffers
      # FlatBuffers binary format parser
      # Reference: https://flatbuffers.dev/md__internals.html
      #
      # FlatBuffers uses offset-based format with vtables for efficient access
      # - Root object offset at beginning of file
      # - Tables have vtables for field lookup
      # - Structs are inline (no vtable)
      # - Strings and vectors are length-prefixed
      class BinaryParser
        attr_reader :schema

        def initialize(schema)
          @schema = schema
        end

        # Parse FlatBuffers binary data
        # @param binary_data [String] Binary FlatBuffers data
        # @return [Hash] Parsed FlatBuffer object
        def parse(binary_data)
          raise ArgumentError, "Binary data cannot be nil" if binary_data.nil?

          if binary_data.empty?
            raise ArgumentError, "Binary data cannot be empty"
          end

          @io = StringIO.new(binary_data)
          @io.set_encoding(Encoding::BINARY)

          # Read root object offset (first 4 bytes)
          root_offset = read_uint32(0)

          # Read root table
          root_table_def = schema.find_table(schema.root_type)
          unless root_table_def
            raise ParseError,
                  "Root type '#{schema.root_type}' not found in schema"
          end

          read_table(root_offset, root_table_def)
        end

        def parse_file(path)
          parse(File.binread(path))
        end

        private

        # Read a table at the given offset
        def read_table(offset, table_def)
          return nil if offset.zero?

          # Read vtable offset (stored as soffset at table location)
          vtable_offset = read_soffset32(offset)
          vtable_pos = offset - vtable_offset

          # Read vtable
          vtable = read_vtable(vtable_pos)

          # Build object from table fields
          result = {}

          table_def.fields.each_with_index do |field_def, index|
            # Field index in vtable
            next if index >= vtable[:field_offsets].size

            field_offset = vtable[:field_offsets][index]
            next if field_offset.zero? # Field not present

            # Calculate absolute position
            field_pos = offset + field_offset

            # Read field value based on type
            value = read_field_value(field_pos, field_def)
            result[field_def.name] = value unless value.nil?
          end

          result
        end

        # Read vtable structure
        def read_vtable(pos)
          vtable_size = read_uint16(pos)
          object_size = read_uint16(pos + 2)

          # Read field offsets (2 bytes each)
          field_count = (vtable_size - 4) / 2
          field_offsets = []

          field_count.times do |i|
            offset = read_uint16(pos + 4 + (i * 2))
            field_offsets << offset
          end

          {
            vtable_size: vtable_size,
            object_size: object_size,
            field_offsets: field_offsets,
          }
        end

        # Read field value based on type
        def read_field_value(pos, field_def)
          if field_def.vector?
            read_vector(pos, field_def)
          elsif field_def.scalar?
            read_scalar(pos, field_def.type)
          elsif field_def.type == "string"
            read_string(pos)
          else
            # User type (table, struct, enum)
            read_user_type(pos, field_def)
          end
        end

        # Read a vector at the given position
        def read_vector(pos, field_def)
          # Vectors are stored as offset to vector data
          vector_offset = read_uoffset32(pos)
          vector_pos = pos + vector_offset

          # Read vector length
          length = read_uint32(vector_pos)
          vector_data_pos = vector_pos + 4

          element_type = field_def.vector_element_type

          # Read vector elements
          elements = []
          length.times do |i|
            element_pos = vector_data_pos + (i * element_size(element_type))
            elements << read_element(element_pos, element_type)
          end

          elements
        end

        # Read a single element
        def read_element(pos, element_type)
          case element_type
          when "byte", "ubyte", "short", "ushort", "int", "uint",
               "long", "ulong", "float", "double", "bool"
            read_scalar(pos, element_type)
          when "string"
            # String in vector is offset
            offset = read_uoffset32(pos)
            read_string(pos + offset)
          else
            # User type
            field_def = Models::Flatbuffers::FieldDefinition.new(
              name: "element",
              type: element_type,
            )
            read_user_type(pos, field_def)
          end
        end

        # Get size of element type
        def element_size(type)
          case type
          when "byte", "ubyte", "bool" then 1
          when "short", "ushort" then 2
          when "int", "uint", "float" then 4
          when "long", "ulong", "double" then 8
          when "string" then 4 # offset
          else 4 # default to offset size
          end
        end

        # Read scalar value
        def read_scalar(pos, type)
          case type
          when "byte" then read_int8(pos)
          when "ubyte" then read_uint8(pos)
          when "short" then read_int16(pos)
          when "ushort" then read_uint16(pos)
          when "int" then read_int32(pos)
          when "uint" then read_uint32(pos)
          when "long" then read_int64(pos)
          when "ulong" then read_uint64(pos)
          when "float" then read_float(pos)
          when "double" then read_double(pos)
          when "bool" then read_uint8(pos) != 0
          else
            raise ParseError, "Unknown scalar type: #{type}"
          end
        end

        # Read user-defined type (table, struct, enum)
        def read_user_type(pos, field_def)
          type_def = schema.find_type(field_def.type)

          case type_def
          when Models::Flatbuffers::TableDefinition
            # Table: read via offset
            offset = read_uoffset32(pos)
            read_table(pos + offset, type_def)
          when Models::Flatbuffers::StructDefinition
            # Struct: read inline
            read_struct(pos, type_def)
          when Models::Flatbuffers::EnumDefinition
            # Enum: read as integer
            value = read_scalar(pos, type_def.type)
            type_def.find_name_by_value(value) || value
          else
            raise ParseError, "Unknown type: #{field_def.type}"
          end
        end

        # Read struct (inline, fixed-size)
        def read_struct(pos, struct_def)
          result = {}
          current_pos = pos

          struct_def.fields.each do |field_def|
            value = if field_def.scalar?
                      read_scalar(current_pos, field_def.type)
                    else
                      # Nested struct
                      nested_struct = schema.find_struct(field_def.type)
                      read_struct(current_pos, nested_struct)
                    end

            result[field_def.name] = value
            current_pos += field_size(field_def)
          end

          result
        end

        # Get size of field for struct
        def field_size(field_def)
          if field_def.scalar?
            element_size(field_def.type)
          else
            # Nested struct size
            nested_struct = schema.find_struct(field_def.type)
            nested_struct.fields.sum { |f| field_size(f) }
          end
        end

        # Read string at position (offset points to length-prefixed string)
        def read_string(pos)
          # String is stored as offset to string data
          offset = read_uoffset32(pos)
          string_pos = pos + offset

          # Read string length
          length = read_uint32(string_pos)

          # Read string data
          @io.seek(string_pos + 4)
          @io.read(length).force_encoding(Encoding::UTF_8)
        end

        # Read methods for different integer types
        def read_int8(pos)
          @io.seek(pos)
          @io.read(1).unpack1("c")
        end

        def read_uint8(pos)
          @io.seek(pos)
          @io.readbyte
        end

        def read_int16(pos)
          @io.seek(pos)
          @io.read(2).unpack1("s<")
        end

        def read_uint16(pos)
          @io.seek(pos)
          @io.read(2).unpack1("S<")
        end

        def read_int32(pos)
          @io.seek(pos)
          @io.read(4).unpack1("l<")
        end

        def read_uint32(pos)
          @io.seek(pos)
          @io.read(4).unpack1("L<")
        end

        def read_int64(pos)
          @io.seek(pos)
          @io.read(8).unpack1("q<")
        end

        def read_uint64(pos)
          @io.seek(pos)
          @io.read(8).unpack1("Q<")
        end

        def read_float(pos)
          @io.seek(pos)
          @io.read(4).unpack1("e")
        end

        def read_double(pos)
          @io.seek(pos)
          @io.read(8).unpack1("E")
        end

        # Read unsigned offset (uoffset32)
        def read_uoffset32(pos)
          read_uint32(pos)
        end

        # Read signed offset (soffset32)
        def read_soffset32(pos)
          read_int32(pos)
        end
      end
    end
  end
end
