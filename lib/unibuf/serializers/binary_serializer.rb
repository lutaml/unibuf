# frozen_string_literal: true

module Unibuf
  module Serializers
    # Binary Protocol Buffer wire format serializer
    # Implements Protocol Buffers binary encoding specification
    # Reference: https://protobuf.dev/programming-guides/encoding/
    class BinarySerializer
      attr_reader :schema

      # Wire types (must match parser)
      WIRE_TYPE_VARINT = 0
      WIRE_TYPE_64BIT = 1
      WIRE_TYPE_LENGTH_DELIMITED = 2
      WIRE_TYPE_32BIT = 5

      def initialize(schema)
        @schema = schema
      end

      # Serialize a Message to binary Protocol Buffer format
      # @param message [Models::Message] The message to serialize
      # @param message_type [String] The message type name from schema
      # @return [String] Binary data
      def serialize(message, message_type: nil)
        raise ArgumentError, "Message cannot be nil" if message.nil?

        # Find message definition
        msg_def = find_message_definition(message_type)
        unless msg_def
          raise ArgumentError,
                "Message type required or schema must have exactly one message"
        end

        # Serialize all fields
        serialize_fields(message, msg_def)
      end

      def serialize_to_file(message, path, message_type: nil)
        binary_data = serialize(message, message_type: message_type)
        File.binwrite(path, binary_data)
      end

      private

      def find_message_definition(type_name)
        return schema.messages.first if type_name.nil? && schema.messages.size == 1

        schema.find_message(type_name)
      end

      def serialize_fields(message, msg_def)
        output = (+"").force_encoding(Encoding::BINARY)

        message.fields.each do |field|
          # Find field definition
          field_def = msg_def.fields.find { |fd| fd.name == field.name }
          next unless field_def # Skip unknown fields

          # Encode field
          encoded_field = encode_field(field, field_def)
          output << encoded_field if encoded_field
        end

        output
      end

      def encode_field(field, field_def)
        # Determine wire type based on field type
        wire_type = wire_type_for_field(field_def)
        return nil unless wire_type

        # Encode tag (field_number << 3) | wire_type
        tag = (field_def.number << 3) | wire_type
        output = encode_varint(tag)

        # Encode value based on wire type
        output << encode_field_value(field, field_def, wire_type)

        output
      end

      def wire_type_for_field(field_def)
        case field_def.type
        when "bool", "int32", "int64", "uint32", "uint64", "sint32", "sint64"
          WIRE_TYPE_VARINT
        when "fixed64", "sfixed64", "double"
          WIRE_TYPE_64BIT
        when "string", "bytes"
          WIRE_TYPE_LENGTH_DELIMITED
        when "fixed32", "sfixed32", "float"
          WIRE_TYPE_32BIT
        else
          # Assume it's a message type
          WIRE_TYPE_LENGTH_DELIMITED
        end
      end

      def encode_field_value(field, field_def, wire_type)
        case wire_type
        when WIRE_TYPE_VARINT
          encode_varint_value(field, field_def)
        when WIRE_TYPE_64BIT
          encode_64bit_value(field, field_def)
        when WIRE_TYPE_LENGTH_DELIMITED
          encode_length_delimited_value(field, field_def)
        when WIRE_TYPE_32BIT
          encode_32bit_value(field, field_def)
        else
          raise SerializationError, "Unsupported wire type: #{wire_type}"
        end
      end

      # Encode varint values
      def encode_varint_value(field, field_def)
        value = field.value

        case field_def.type
        when "bool"
          encode_varint(value ? 1 : 0)
        when "int32", "int64", "uint32", "uint64"
          encode_varint(value)
        when "sint32"
          encode_varint(encode_zigzag_32(value))
        when "sint64"
          encode_varint(encode_zigzag_64(value))
        else
          encode_varint(value)
        end
      end

      # Encode 64-bit values
      def encode_64bit_value(field, field_def)
        value = field.value

        case field_def.type
        when "fixed64"
          [value].pack("Q<")
        when "sfixed64"
          [value].pack("q<")
        when "double"
          [value].pack("E")
        else
          [value].pack("Q<")
        end
      end

      # Encode 32-bit values
      def encode_32bit_value(field, field_def)
        value = field.value

        case field_def.type
        when "fixed32"
          [value].pack("L<")
        when "sfixed32"
          [value].pack("l<")
        when "float"
          [value].pack("e")
        else
          [value].pack("L<")
        end
      end

      # Encode length-delimited values
      def encode_length_delimited_value(field, field_def)
        value = field.value

        case field_def.type
        when "string"
          bytes = value.dup.force_encoding(Encoding::UTF_8)
          encode_varint(bytes.bytesize) + bytes
        when "bytes"
          encode_varint(value.bytesize) + value
        else
          # Embedded message
          nested_msg = field.as_message
          nested_msg_def = schema.find_message(field_def.type)
          unless nested_msg_def
            raise SerializationError,
                  "Unknown message type: #{field_def.type}"
          end

          nested_bytes = serialize_fields(nested_msg, nested_msg_def)
          encode_varint(nested_bytes.bytesize) + nested_bytes
        end
      end

      # Encode variable-length integer
      # Values 0-127: 1 byte
      # Larger values: multiple bytes with continuation bit
      def encode_varint(value)
        return "\x00".b if value.zero?

        output = (+"").force_encoding(Encoding::BINARY)

        while value.positive?
          byte = value & 0x7F
          value >>= 7
          byte |= 0x80 if value.positive?
          output << byte.chr
        end

        output
      end

      # Encode ZigZag for signed 32-bit integers
      # Maps signed integers to unsigned for efficient encoding
      def encode_zigzag_32(value)
        (value << 1) ^ (value >> 31)
      end

      # Encode ZigZag for signed 64-bit integers
      def encode_zigzag_64(value)
        (value << 1) ^ (value >> 63)
      end
    end
  end
end
