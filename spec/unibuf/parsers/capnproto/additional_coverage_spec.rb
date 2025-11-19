# frozen_string_literal: true

require "spec_helper"
require "unibuf/models/capnproto/schema"
require "unibuf/models/capnproto/struct_definition"
require "unibuf/models/capnproto/field_definition"
require "unibuf/models/capnproto/enum_definition"
require "unibuf/parsers/capnproto/binary_parser"
require "unibuf/serializers/capnproto/binary_serializer"

RSpec.describe "Cap'n Proto Additional Coverage" do
  let(:fixture_path) { File.join(__dir__, "../../../fixtures/addressbook.capnp") }
  let(:schema) { Unibuf.parse_capnproto_schema(fixture_path) }

  describe "All primitive types" do
    it "handles all integer types" do
      test_schema = Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "AllTypes",
            fields: [
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "i8", ordinal: 0, type: "Int8"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "u8", ordinal: 1, type: "UInt8"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "i16", ordinal: 2, type: "Int16"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "u16", ordinal: 3, type: "UInt16"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "i32", ordinal: 4, type: "Int32"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "u32", ordinal: 5, type: "UInt32"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "i64", ordinal: 6, type: "Int64"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "u64", ordinal: 7, type: "UInt64"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "f32", ordinal: 8, type: "Float32"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "f64", ordinal: 9, type: "Float64"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "bool", ordinal: 10, type: "Bool"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "void", ordinal: 11, type: "Void")
            ]
          )
        ]
      )

      data = {
        i8: -1, u8: 255,
        i16: -100, u16: 1000,
        i32: -50000, u32: 50000,
        i64: -1000000, u64: 1000000,
        f32: 3.14, f64: 2.718,
        bool: true, void: nil
      }

      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(test_schema)
      binary = serializer.serialize(data, root_type: "AllTypes")

      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(test_schema)
      result = parser.parse(binary, root_type: "AllTypes")

      expect(result[:i8]).to eq(-1)
      expect(result[:u8]).to eq(255)
      expect(result[:bool]).to be true
      expect(result[:void]).to be_nil
    end
  end

  describe "Data type handling" do
    it "serializes and parses Data fields" do
      test_schema = Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "Container",
            fields: [
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "data", ordinal: 0, type: "Data")
            ]
          )
        ]
      )

      binary_data = [0, 1, 2, 255].pack("C*")
      data = { data: binary_data }

      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(test_schema)
      binary = serializer.serialize(data, root_type: "Container")

      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(test_schema)
      result = parser.parse(binary, root_type: "Container")

      expect(result[:data]).to eq(binary_data)
    end
  end

  describe "Enum handling in structs" do
    it "serializes and parses enum fields" do
      test_schema = Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "Item",
            fields: [
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "status", ordinal: 0, type: "Status")
            ]
          )
        ],
        enums: [
          Unibuf::Models::Capnproto::EnumDefinition.new(
            name: "Status",
            values: { "active" => 0, "inactive" => 1, "pending" => 2 }
          )
        ]
      )

      data = { status: "active" }

      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(test_schema)
      binary = serializer.serialize(data, root_type: "Item")

      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(test_schema)
      result = parser.parse(binary, root_type: "Item")

      expect(result[:status]).to eq("active")
    end

    it "handles enum values as integers" do
      test_schema = Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "Item",
            fields: [
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "status", ordinal: 0, type: "Status")
            ]
          )
        ],
        enums: [
          Unibuf::Models::Capnproto::EnumDefinition.new(
            name: "Status",
            values: { "active" => 0, "inactive" => 1 }
          )
        ]
      )

      data = { status: 1 }

      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(test_schema)
      binary = serializer.serialize(data, root_type: "Item")

      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(test_schema)
      result = parser.parse(binary, root_type: "Item")

      expect(result[:status]).to eq("inactive")
    end
  end

  describe "Nested struct handling" do
    it "serializes and parses nested structs" do
      inner_struct = Unibuf::Models::Capnproto::StructDefinition.new(
        name: "Inner",
        fields: [
          Unibuf::Models::Capnproto::FieldDefinition.new(name: "value", ordinal: 0, type: "UInt32")
        ]
      )

      test_schema = Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "Outer",
            fields: [
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "inner", ordinal: 0, type: "Inner")
            ]
          ),
          inner_struct
        ]
      )

      data = { inner: { value: 42 } }

      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(test_schema)
      binary = serializer.serialize(data, root_type: "Outer")

      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(test_schema)
      result = parser.parse(binary, root_type: "Outer")

      expect(result[:inner][:value]).to eq(42)
    end
  end

  describe "List of primitives" do
    it "serializes and parses lists of various primitive types" do
      test_schema = Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "Container",
            fields: [
              Unibuf::Models::Capnproto::FieldDefinition.new(
                name: "numbers",
                ordinal: 0,
                type: { generic: "List", element_type: "UInt32" }
              )
            ]
          )
        ]
      )

      data = { numbers: [1, 2, 3, 4, 5] }

      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(test_schema)
      binary = serializer.serialize(data, root_type: "Container")

      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(test_schema)
      result = parser.parse(binary, root_type: "Container")

      expect(result[:numbers]).to eq([1, 2, 3, 4, 5])
    end
  end

  describe "Empty and nil field handling" do
    it "handles nil values gracefully" do
      data = { id: nil, name: nil, email: nil, phones: nil }

      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(schema)
      binary = serializer.serialize(data, root_type: "Person")

      expect(binary).to be_a(String)
      expect(binary.length).to be > 0
    end

    it "handles empty lists" do
      data = { id: 1, name: "Test", email: "test@example.com", phones: [] }

      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(schema)
      binary = serializer.serialize(data, root_type: "Person")

      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(schema)
      result = parser.parse(binary, root_type: "Person")

      expect(result[:id]).to eq(1)
      expect(result[:name]).to eq("Test")
    end
  end

  describe "Pointer index calculations" do
    it "correctly calculates pointer indices with mixed fields" do
      test_schema = Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "Mixed",
            fields: [
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "id", ordinal: 0, type: "UInt32"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "name", ordinal: 1, type: "Text"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "count", ordinal: 2, type: "Int32"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "email", ordinal: 3, type: "Text")
            ]
          )
        ]
      )

      data = { id: 1, name: "Alice", count: 10, email: "alice@example.com" }

      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(test_schema)
      binary = serializer.serialize(data, root_type: "Mixed")

      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(test_schema)
      result = parser.parse(binary, root_type: "Mixed")

      expect(result[:id]).to eq(1)
      expect(result[:name]).to eq("Alice")
      expect(result[:count]).to eq(10)
      expect(result[:email]).to eq("alice@example.com")
    end
  end
end