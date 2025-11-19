# frozen_string_literal: true

module Unibuf
  module Serializers
    module Flatbuffers
      # FlatBuffers binary format serializer - Pure Ruby
      class BinarySerializer
        attr_reader :schema

        def initialize(schema)
          @schema = schema
        end

        def serialize(data)
          raise ArgumentError, "Data cannot be nil" if data.nil?

          root_table_def = schema.find_table(schema.root_type)
          unless root_table_def
            raise Unibuf::SerializationError,
                  "Root type '#{schema.root_type}' not found in schema"
          end

          # Manual buffer construction
          parts = []

          # Serialize table and collect parts
          table_parts = serialize_table(data, root_table_def)

          # Calculate positions
          root_offset = 4  # After root offset itself

          # Build final buffer
          buffer = [root_offset].pack("L<")  # Root offset
          buffer += table_parts.pack("C*")

          buffer
        end

        def serialize_to_file(data, path)
          File.binwrite(path, serialize(data))
        end

        private

        def serialize_table(data, table_def)
          # PHASE 1: Write strings (out-of-line data)
          string_data = {}
          string_bytes_total = []

          table_def.fields.each do |field_def|
            value = data[field_def.name]
            next unless value && field_def.type == "string"

            # Serialize string
            str_bytes = []
            str_bytes.concat([value.bytesize].pack("L<").bytes)  # length
            str_bytes.concat(value.bytes)  # content
            str_bytes << 0  # null terminator

            # Align to 4
            while (str_bytes.size % 4) != 0
              str_bytes << 0
            end

            string_data[field_def.name] = {
              bytes: str_bytes,
              start_in_string_section: string_bytes_total.size
            }
            string_bytes_total.concat(str_bytes)
          end

          # PHASE 2: Build table
          table_bytes = []

          # Reserve vtable offset
          table_bytes.concat([0, 0, 0, 0])

          # Calculate vtable size
          vtable_size = 4 + (table_def.fields.size * 2)

          # Write fields
          field_offsets = []
          current_pos = 4  # Start after vtable offset

          table_def.fields.each do |field_def|
            value = data[field_def.name]

            if value.nil?
              field_offsets << 0
            elsif field_def.scalar?
              field_offsets << current_pos
              # Write scalar value
              case field_def.type
              when "byte"
                table_bytes.concat([value].pack("c").bytes)
                current_pos += 1
              when "ubyte", "bool"
                val = value.is_a?(TrueClass) ? 1 : (value.is_a?(FalseClass) ? 0 : value)
                table_bytes << (val & 0xFF)
                current_pos += 1
              when "short"
                table_bytes.concat([value].pack("s<").bytes)
                current_pos += 2
              when "ushort"
                table_bytes.concat([value].pack("S<").bytes)
                current_pos += 2
              when "int"
                table_bytes.concat([value].pack("l<").bytes)
                current_pos += 4
              when "uint"
                table_bytes.concat([value].pack("L<").bytes)
                current_pos += 4
              when "long"
                table_bytes.concat([value].pack("q<").bytes)
                current_pos += 8
              when "ulong"
                table_bytes.concat([value].pack("Q<").bytes)
                current_pos += 8
              when "float"
                table_bytes.concat([value].pack("e").bytes)
                current_pos += 4
              when "double"
                table_bytes.concat([value].pack("E").bytes)
                current_pos += 8
              end
            elsif field_def.type == "string" && string_data[field_def.name]
              field_offsets << current_pos
              # Calculate uoffset from current field position to string
              # String will be at: 4 (root) + table_size + vtable_size + string_start
              str_info = string_data[field_def.name]
              table_size = table_bytes.size + 4  # +4 for remaining field
              string_abs_pos = 4 + table_size + vtable_size + str_info[:start_in_string_section]
              # uoffset from field position in final buffer
              field_abs_pos = 4 + current_pos
              uoffset = string_abs_pos - field_abs_pos
              table_bytes.concat([uoffset].pack("L<").bytes)
              current_pos += 4
            else
              field_offsets << 0
            end
          end

          # PHASE 3: Build vtable
          vtable_bytes = []
          object_size = table_bytes.size

          vtable_bytes.concat([vtable_size].pack("S<").bytes)
          vtable_bytes.concat([object_size].pack("S<").bytes)
          field_offsets.each { |off| vtable_bytes.concat([off].pack("S<").bytes) }

          # Patch vtable offset
          vtable_offset = -(object_size)
          table_bytes[0..3] = [vtable_offset].pack("l<").bytes

          # Return table + vtable + strings
          table_bytes + vtable_bytes + string_bytes_total
        end
      end
    end
  end
end