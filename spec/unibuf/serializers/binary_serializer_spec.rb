# frozen_string_literal: true

require "spec_helper"
require_relative "../../../lib/unibuf/serializers/binary_serializer"

RSpec.describe Unibuf::Serializers::BinarySerializer do
  let(:schema) do
    field_def = Unibuf::Models::FieldDefinition.new(
      name: "test",
      type: "string",
      number: 1,
    )

    msg_def = Unibuf::Models::MessageDefinition.new(
      name: "TestMessage",
      fields: [field_def],
    )

    Unibuf::Models::Schema.new(
      messages: [msg_def],
    )
  end

  let(:serializer) { described_class.new(schema) }

  describe "initialization" do
    it "creates with schema" do
      expect(serializer.schema).to eq(schema)
    end
  end

  describe "varint encoding" do
    it "encodes zero" do
      result = serializer.send(:encode_varint, 0)
      expect(result.bytes).to eq([0x00])
    end

    it "encodes single-byte varint" do
      result = serializer.send(:encode_varint, 127)
      expect(result.bytes).to eq([127])
    end

    it "encodes multi-byte varint" do
      # 300 = 0xAC 0x02 in varint encoding
      result = serializer.send(:encode_varint, 300)
      expect(result.bytes).to eq([0xAC, 0x02])
    end

    it "encodes large numbers" do
      result = serializer.send(:encode_varint, 0xFFFFFFFF)
      expect(result.bytesize).to be > 1
    end
  end

  describe "zigzag encoding" do
    context "32-bit" do
      it "encodes zero" do
        expect(serializer.send(:encode_zigzag_32, 0)).to eq(0)
      end

      it "encodes positive values" do
        expect(serializer.send(:encode_zigzag_32, 1)).to eq(2)
        expect(serializer.send(:encode_zigzag_32, 2)).to eq(4)
      end

      it "encodes negative values" do
        expect(serializer.send(:encode_zigzag_32, -1)).to eq(1)
        expect(serializer.send(:encode_zigzag_32, -2)).to eq(3)
      end
    end

    context "64-bit" do
      it "encodes zero" do
        expect(serializer.send(:encode_zigzag_64, 0)).to eq(0)
      end

      it "encodes positive values" do
        expect(serializer.send(:encode_zigzag_64, 1)).to eq(2)
        expect(serializer.send(:encode_zigzag_64, 2)).to eq(4)
      end

      it "encodes negative values" do
        expect(serializer.send(:encode_zigzag_64, -1)).to eq(1)
        expect(serializer.send(:encode_zigzag_64, -2)).to eq(3)
      end
    end
  end

  describe "wire type detection" do
    it "identifies varint types" do
      field_def = Unibuf::Models::FieldDefinition.new(name: "x", type: "int32",
                                                      number: 1)
      expect(serializer.send(:wire_type_for_field, field_def)).to eq(0)
    end

    it "identifies 64-bit types" do
      field_def = Unibuf::Models::FieldDefinition.new(name: "x",
                                                      type: "fixed64", number: 1)
      expect(serializer.send(:wire_type_for_field, field_def)).to eq(1)
    end

    it "identifies length-delimited types" do
      field_def = Unibuf::Models::FieldDefinition.new(name: "x",
                                                      type: "string", number: 1)
      expect(serializer.send(:wire_type_for_field, field_def)).to eq(2)
    end

    it "identifies 32-bit types" do
      field_def = Unibuf::Models::FieldDefinition.new(name: "x",
                                                      type: "fixed32", number: 1)
      expect(serializer.send(:wire_type_for_field, field_def)).to eq(5)
    end
  end

  describe "field type serialization" do
    context "varint types" do
      it "serializes bool" do
        field_def = Unibuf::Models::FieldDefinition.new(name: "flag",
                                                        type: "bool", number: 1)
        field = Unibuf::Models::Field.new(name: "flag", value: true)

        result = serializer.send(:encode_varint_value, field, field_def)
        expect(result.bytes).to eq([0x01])
      end

      it "serializes int32" do
        field_def = Unibuf::Models::FieldDefinition.new(name: "num",
                                                        type: "int32", number: 1)
        field = Unibuf::Models::Field.new(name: "num", value: 150)

        result = serializer.send(:encode_varint_value, field, field_def)
        expect(result.bytes).to eq([0x96, 0x01])
      end

      it "serializes sint32 with zigzag" do
        field_def = Unibuf::Models::FieldDefinition.new(name: "num",
                                                        type: "sint32", number: 1)
        field = Unibuf::Models::Field.new(name: "num", value: -1)

        result = serializer.send(:encode_varint_value, field, field_def)
        # -1 encoded as zigzag = 1
        expect(result.bytes).to eq([0x01])
      end
    end

    context "64-bit types" do
      it "serializes fixed64" do
        field_def = Unibuf::Models::FieldDefinition.new(name: "num",
                                                        type: "fixed64", number: 1)
        field = Unibuf::Models::Field.new(name: "num", value: 12345)

        result = serializer.send(:encode_64bit_value, field, field_def)
        expect(result.bytesize).to eq(8)
      end

      it "serializes double" do
        field_def = Unibuf::Models::FieldDefinition.new(name: "num",
                                                        type: "double", number: 1)
        field = Unibuf::Models::Field.new(name: "num", value: 3.14)

        result = serializer.send(:encode_64bit_value, field, field_def)
        expect(result.bytesize).to eq(8)
      end
    end

    context "32-bit types" do
      it "serializes fixed32" do
        field_def = Unibuf::Models::FieldDefinition.new(name: "num",
                                                        type: "fixed32", number: 1)
        field = Unibuf::Models::Field.new(name: "num", value: 12345)

        result = serializer.send(:encode_32bit_value, field, field_def)
        expect(result.bytesize).to eq(4)
      end

      it "serializes float" do
        field_def = Unibuf::Models::FieldDefinition.new(name: "num",
                                                        type: "float", number: 1)
        field = Unibuf::Models::Field.new(name: "num", value: 3.14)

        result = serializer.send(:encode_32bit_value, field, field_def)
        expect(result.bytesize).to eq(4)
      end
    end

    context "length-delimited types" do
      it "serializes string" do
        field_def = Unibuf::Models::FieldDefinition.new(name: "text",
                                                        type: "string", number: 1)
        field = Unibuf::Models::Field.new(name: "text", value: "hello")

        result = serializer.send(:encode_length_delimited_value, field,
                                 field_def)
        # Length prefix (5) + "hello"
        expect(result.bytes[0]).to eq(5)
        expect(result[1..]).to eq("hello")
      end

      it "serializes bytes" do
        field_def = Unibuf::Models::FieldDefinition.new(name: "data",
                                                        type: "bytes", number: 1)
        field = Unibuf::Models::Field.new(name: "data", value: "\x01\x02\x03".b)

        result = serializer.send(:encode_length_delimited_value, field,
                                 field_def)
        expect(result.bytes[0]).to eq(3)
        expect(result[1..].bytes).to eq([0x01, 0x02, 0x03])
      end
    end
  end

  describe "message serialization" do
    let(:string_field_schema) do
      field_def = Unibuf::Models::FieldDefinition.new(
        name: "name",
        type: "string",
        number: 1,
      )

      msg_def = Unibuf::Models::MessageDefinition.new(
        name: "Person",
        fields: [field_def],
      )

      Unibuf::Models::Schema.new(messages: [msg_def])
    end

    it "serializes simple message" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "Alice" },
        ],
      )

      result = described_class.new(string_field_schema)
        .serialize(message)

      expect(result).not_to be_empty
      expect(result.encoding).to eq(Encoding::BINARY)
    end

    it "raises on nil message" do
      expect do
        serializer.serialize(nil)
      end.to raise_error(ArgumentError, /nil/)
    end

    it "handles empty message" do
      message = Unibuf::Models::Message.new("fields" => [])
      result = serializer.serialize(message)
      expect(result).to eq("")
    end
  end

  describe "round-trip serialization" do
    let(:int_schema) do
      field_def = Unibuf::Models::FieldDefinition.new(
        name: "age",
        type: "int32",
        number: 1,
      )

      msg_def = Unibuf::Models::MessageDefinition.new(
        name: "Person",
        fields: [field_def],
      )

      Unibuf::Models::Schema.new(messages: [msg_def])
    end

    it "round-trips integer values" do
      original_message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "age", "value" => 25 },
        ],
      )

      # Serialize
      serializer_instance = described_class.new(int_schema)
      binary_data = serializer_instance.serialize(original_message)

      # Parse back
      parser = Unibuf::Parsers::Binary::WireFormatParser.new(int_schema)
      parsed_message = parser.parse(binary_data)

      # Compare
      expect(parsed_message.find_field("age").value).to eq(25)
    end

    it "round-trips string values" do
      string_schema = Unibuf::Models::Schema.new(
        messages: [
          Unibuf::Models::MessageDefinition.new(
            name: "Message",
            fields: [
              Unibuf::Models::FieldDefinition.new(
                name: "text",
                type: "string",
                number: 1,
              ),
            ],
          ),
        ],
      )

      original_message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "text", "value" => "Hello, World!" },
        ],
      )

      # Serialize
      serializer_instance = described_class.new(string_schema)
      binary_data = serializer_instance.serialize(original_message)

      # Parse back
      parser = Unibuf::Parsers::Binary::WireFormatParser.new(string_schema)
      parsed_message = parser.parse(binary_data)

      # Compare
      expect(parsed_message.find_field("text").value).to eq("Hello, World!")
    end
  end

  describe "nested message serialization" do
    let(:nested_schema) do
      address_def = Unibuf::Models::MessageDefinition.new(
        name: "Address",
        fields: [
          Unibuf::Models::FieldDefinition.new(
            name: "city",
            type: "string",
            number: 1,
          ),
        ],
      )

      person_def = Unibuf::Models::MessageDefinition.new(
        name: "Person",
        fields: [
          Unibuf::Models::FieldDefinition.new(
            name: "name",
            type: "string",
            number: 1,
          ),
          Unibuf::Models::FieldDefinition.new(
            name: "address",
            type: "Address",
            number: 2,
          ),
        ],
      )

      Unibuf::Models::Schema.new(
        messages: [address_def, person_def],
      )
    end

    it "serializes nested messages" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "Alice" },
          {
            "name" => "address",
            "value" => {
              "fields" => [
                { "name" => "city", "value" => "NYC" },
              ],
            },
          },
        ],
      )

      serializer_instance = described_class.new(nested_schema)
      result = serializer_instance.serialize(message, message_type: "Person")

      expect(result).not_to be_empty
      expect(result.encoding).to eq(Encoding::BINARY)
    end

    it "round-trips nested messages" do
      original_message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "Bob" },
          {
            "name" => "address",
            "value" => {
              "fields" => [
                { "name" => "city", "value" => "SF" },
              ],
            },
          },
        ],
      )

      # Serialize
      serializer_instance = described_class.new(nested_schema)
      binary_data = serializer_instance.serialize(original_message,
                                                  message_type: "Person")

      # Parse back
      parser = Unibuf::Parsers::Binary::WireFormatParser.new(nested_schema)
      parsed_message = parser.parse(binary_data, message_type: "Person")

      # Verify
      expect(parsed_message.find_field("name").value).to eq("Bob")
      address_field = parsed_message.find_field("address")
      expect(address_field).not_to be_nil
      address_msg = address_field.as_message
      expect(address_msg.find_field("city").value).to eq("SF")
    end
  end

  describe "wire type constants" do
    it "defines standard wire types" do
      expect(described_class::WIRE_TYPE_VARINT).to eq(0)
      expect(described_class::WIRE_TYPE_64BIT).to eq(1)
      expect(described_class::WIRE_TYPE_LENGTH_DELIMITED).to eq(2)
      expect(described_class::WIRE_TYPE_32BIT).to eq(5)
    end
  end
end
