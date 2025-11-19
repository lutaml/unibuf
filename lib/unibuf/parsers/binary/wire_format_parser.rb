# frozen_string_literal: true

require "bindata"

module Unibuf
  module Parsers
    module Binary
      # Binary Protocol Buffer wire format parser
      # Implements Protocol Buffers binary encoding specification
      # Reference: https://protobuf.dev/programming-guides/encoding/
      class WireFormatParser
        attr_reader :schema

        # Wire types
        WIRE_TYPE_VARINT = 0
        WIRE_TYPE_64BIT = 1
        WIRE_TYPE_LENGTH_DELIMITED = 2
        WIRE_TYPE_START_GROUP = 3  # Deprecated
        WIRE_TYPE_END_GROUP = 4    # Deprecated
        WIRE_TYPE_32BIT = 5

        def initialize(schema)
          @schema = schema
        end

        # Parse binary Protocol Buffer data
        # @param binary_data [String] Binary data
        # @return [Models::Message] Parsed message
        def parse(binary_data, message_type: nil)
          raise ArgumentError, "Binary data cannot be nil" if binary_data.nil?
          raise ArgumentError, "Binary data cannot be empty" if binary_data.empty?

          # Find message definition
          msg_def = find_message_definition(message_type)
          raise ArgumentError, "Message type required or schema must have exactly one message" unless msg_def

          begin
            # Parse fields from binary
            fields = parse_fields(binary_data, msg_def)

            # Build Message model
            Models::Message.new("fields" => fields)
          rescue EOFError => e
            raise ParseError, "Unexpected end of data: #{e.message}"
          end
        end

        def parse_file(path, message_type: nil)
          parse(File.binread(path), message_type: message_type)
        end

        private

        def find_message_definition(type_name)
          return schema.messages.first if type_name.nil? && schema.messages.size == 1

          schema.find_message(type_name)
        end

        def parse_fields(data, msg_def)
          fields = []
          io = StringIO.new(data)
          io.set_encoding(Encoding::BINARY)

          until io.eof?
            begin
              # Read field tag
              tag = read_varint(io)
              field_number = tag >> 3
              wire_type = tag & 0x7

              # Find field definition
              field_def = msg_def.find_field_by_number(field_number)
              next unless field_def # Skip unknown fields

              # Parse field value based on wire type
              value = parse_field_value(io, wire_type, field_def)

              fields << {
                "name" => field_def.name,
                "value" => value
              }
            rescue EOFError => e
              raise ParseError, "Incomplete field data: #{e.message}"
            end
          end

          fields
        end

        def parse_field_value(io, wire_type, field_def)
          case wire_type
          when WIRE_TYPE_VARINT
            parse_varint_value(io, field_def)
          when WIRE_TYPE_64BIT
            parse_64bit_value(io, field_def)
          when WIRE_TYPE_LENGTH_DELIMITED
            parse_length_delimited_value(io, field_def)
          when WIRE_TYPE_32BIT
            parse_32bit_value(io, field_def)
          else
            raise ParseError, "Unsupported wire type: #{wire_type}"
          end
        end

        def parse_varint_value(io, field_def)
          value = read_varint(io)

          case field_def.type
          when "bool"
            value != 0
          when "int32", "int64", "uint32", "uint64"
            value
          when "sint32"
            decode_zigzag_32(value)
          when "sint64"
            decode_zigzag_64(value)
          else
            value
          end
        end

        def parse_64bit_value(io, field_def)
          bytes = io.read(8)
          raise ParseError, "Unexpected EOF reading 64-bit value" unless bytes && bytes.bytesize == 8

          case field_def.type
          when "fixed64"
            bytes.unpack1("Q<")
          when "sfixed64"
            bytes.unpack1("q<")
          when "double"
            bytes.unpack1("E")
          else
            bytes.unpack1("Q<")
          end
        end

        def parse_32bit_value(io, field_def)
          bytes = io.read(4)
          raise ParseError, "Unexpected EOF reading 32-bit value" unless bytes && bytes.bytesize == 4

          case field_def.type
          when "fixed32"
            bytes.unpack1("L<")
          when "sfixed32"
            bytes.unpack1("l<")
          when "float"
            bytes.unpack1("e")
          else
            bytes.unpack1("L<")
          end
        end

        def parse_length_delimited_value(io, field_def)
          length = read_varint(io)
          bytes = io.read(length)
          raise ParseError, "Unexpected EOF reading length-delimited value" unless bytes && bytes.bytesize == length

          case field_def.type
          when "string"
            bytes.force_encoding(Encoding::UTF_8)
          when "bytes"
            bytes
          else
            # Embedded message
            nested_msg_def = schema.find_message(field_def.type)
            if nested_msg_def
              nested_fields = parse_fields(bytes, nested_msg_def)
              { "fields" => nested_fields }
            else
              bytes
            end
          end
        end

        # Read varint (variable-length integer)
        def read_varint(io)
          result = 0
          shift = 0

          loop do
            byte = io.readbyte
            result |= (byte & 0x7F) << shift
            break if (byte & 0x80).zero?

            shift += 7
            raise ParseError, "Varint too long" if shift >= 64
          end

          result
        rescue EOFError => e
          raise ParseError, "Unexpected EOF reading varint: #{e.message}"
        end

        # Decode ZigZag encoding for signed integers
        def decode_zigzag_32(value)
          (value >> 1) ^ -(value & 1)
        end

        def decode_zigzag_64(value)
          (value >> 1) ^ -(value & 1)
        end
      end
    end
  end
end
