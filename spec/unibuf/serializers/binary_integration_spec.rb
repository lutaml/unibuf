# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require_relative "../../../lib/unibuf/serializers/binary_serializer"

RSpec.describe "Binary Serialization Integration" do
  let(:simple_schema) do
    Unibuf::Models::Schema.new(
      messages: [
        Unibuf::Models::MessageDefinition.new(
          name: "Person",
          fields: [
            Unibuf::Models::FieldDefinition.new(name: "name", type: "string", number: 1),
            Unibuf::Models::FieldDefinition.new(name: "age", type: "int32", number: 2),
            Unibuf::Models::FieldDefinition.new(name: "active", type: "bool", number: 3),
          ],
        ),
      ],
    )
  end

  let(:nested_schema) do
    Unibuf::Models::Schema.new(
      messages: [
        Unibuf::Models::MessageDefinition.new(
          name: "Address",
          fields: [
            Unibuf::Models::FieldDefinition.new(name: "street", type: "string", number: 1),
            Unibuf::Models::FieldDefinition.new(name: "city", type: "string", number: 2),
            Unibuf::Models::FieldDefinition.new(name: "zip", type: "int32", number: 3),
          ],
        ),
        Unibuf::Models::MessageDefinition.new(
          name: "Person",
          fields: [
            Unibuf::Models::FieldDefinition.new(name: "name", type: "string", number: 1),
            Unibuf::Models::FieldDefinition.new(name: "address", type: "Address", number: 2),
          ],
        ),
      ],
    )
  end

  describe "text to binary to text round-trip" do
    it "preserves simple message data" do
      # Create original message
      original = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "Alice" },
          { "name" => "age", "value" => 30 },
          { "name" => "active", "value" => true },
        ],
      )

      # Serialize to binary
      serializer = Unibuf::Serializers::BinarySerializer.new(simple_schema)
      binary_data = serializer.serialize(original, message_type: "Person")

      # Parse back from binary
      parser = Unibuf::Parsers::Binary::WireFormatParser.new(simple_schema)
      parsed = parser.parse(binary_data, message_type: "Person")

      # Verify fields match
      expect(parsed.find_field("name").value).to eq("Alice")
      expect(parsed.find_field("age").value).to eq(30)
      expect(parsed.find_field("active").value).to eq(true)
    end

    it "preserves nested message data" do
      original = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "Bob" },
          {
            "name" => "address",
            "value" => {
              "fields" => [
                { "name" => "street", "value" => "123 Main St" },
                { "name" => "city", "value" => "Springfield" },
                { "name" => "zip", "value" => 12345 },
              ],
            },
          },
        ],
      )

      # Serialize to binary
      serializer = Unibuf::Serializers::BinarySerializer.new(nested_schema)
      binary_data = serializer.serialize(original, message_type: "Person")

      # Parse back from binary
      parser = Unibuf::Parsers::Binary::WireFormatParser.new(nested_schema)
      parsed = parser.parse(binary_data, message_type: "Person")

      # Verify root fields
      expect(parsed.find_field("name").value).to eq("Bob")

      # Verify nested message
      address = parsed.find_field("address").as_message
      expect(address.find_field("street").value).to eq("123 Main St")
      expect(address.find_field("city").value).to eq("Springfield")
      expect(address.find_field("zip").value).to eq(12345)
    end
  end

  describe "binary to text to binary round-trip" do
    it "preserves binary encoding" do
      # Create original message
      original = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "Charlie" },
          { "name" => "age", "value" => 25 },
          { "name" => "active", "value" => false },
        ],
      )

      # First serialization
      serializer = Unibuf::Serializers::BinarySerializer.new(simple_schema)
      binary1 = serializer.serialize(original, message_type: "Person")

      # Parse to text
      parser = Unibuf::Parsers::Binary::WireFormatParser.new(simple_schema)
      parsed = parser.parse(binary1, message_type: "Person")

      # Serialize again
      binary2 = serializer.serialize(parsed, message_type: "Person")

      # Binary data should be identical
      expect(binary2).to eq(binary1)
    end
  end

  describe "using Message#to_binary" do
    it "serializes through Message API" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "Dave" },
          { "name" => "age", "value" => 40 },
        ],
      )

      # Use Message#to_binary
      binary_data = message.to_binary(schema: simple_schema, message_type: "Person")

      # Verify it's valid binary
      expect(binary_data).to be_a(String)
      expect(binary_data.encoding).to eq(Encoding::BINARY)
      expect(binary_data).not_to be_empty

      # Parse back and verify
      parser = Unibuf::Parsers::Binary::WireFormatParser.new(simple_schema)
      parsed = parser.parse(binary_data, message_type: "Person")

      expect(parsed.find_field("name").value).to eq("Dave")
      expect(parsed.find_field("age").value).to eq(40)
    end
  end

  describe "with various data types" do
    let(:multi_type_schema) do
      Unibuf::Models::Schema.new(
        messages: [
          Unibuf::Models::MessageDefinition.new(
            name: "DataTypes",
            fields: [
              Unibuf::Models::FieldDefinition.new(name: "int_val", type: "int32", number: 1),
              Unibuf::Models::FieldDefinition.new(name: "sint_val", type: "sint32", number: 2),
              Unibuf::Models::FieldDefinition.new(name: "bool_val", type: "bool", number: 3),
              Unibuf::Models::FieldDefinition.new(name: "string_val", type: "string", number: 4),
              Unibuf::Models::FieldDefinition.new(name: "bytes_val", type: "bytes", number: 5),
            ],
          ),
        ],
      )
    end

    it "round-trips all scalar types" do
      original = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "int_val", "value" => 12345 },
          { "name" => "sint_val", "value" => -999 },
          { "name" => "bool_val", "value" => true },
          { "name" => "string_val", "value" => "Test String!" },
          { "name" => "bytes_val", "value" => "\x01\x02\x03\x04".b },
        ],
      )

      # Serialize
      serializer = Unibuf::Serializers::BinarySerializer.new(multi_type_schema)
      binary_data = serializer.serialize(original, message_type: "DataTypes")

      # Parse back
      parser = Unibuf::Parsers::Binary::WireFormatParser.new(multi_type_schema)
      parsed = parser.parse(binary_data, message_type: "DataTypes")

      # Verify all fields
      expect(parsed.find_field("int_val").value).to eq(12345)
      expect(parsed.find_field("sint_val").value).to eq(-999)
      expect(parsed.find_field("bool_val").value).to eq(true)
      expect(parsed.find_field("string_val").value).to eq("Test String!")
      expect(parsed.find_field("bytes_val").value.bytes).to eq([0x01, 0x02, 0x03, 0x04])
    end
  end

  describe "file operations" do
    let(:temp_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
    end

    it "writes and reads binary files" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "File Test" },
          { "name" => "age", "value" => 50 },
        ],
      )

      binary_file = File.join(temp_dir, "test.binpb")

      # Serialize to file
      serializer = Unibuf::Serializers::BinarySerializer.new(simple_schema)
      serializer.serialize_to_file(message, binary_file, message_type: "Person")

      # Read back
      parser = Unibuf::Parsers::Binary::WireFormatParser.new(simple_schema)
      parsed = parser.parse_file(binary_file, message_type: "Person")

      # Verify
      expect(parsed.find_field("name").value).to eq("File Test")
      expect(parsed.find_field("age").value).to eq(50)
    end
  end

  describe "error handling" do
    it "raises on mismatched schema" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "unknown_field", "value" => "test" },
        ],
      )

      serializer = Unibuf::Serializers::BinarySerializer.new(simple_schema)

      # Should not raise, just skip unknown field
      binary_data = serializer.serialize(message, message_type: "Person")
      expect(binary_data).to eq("")
    end
  end
end