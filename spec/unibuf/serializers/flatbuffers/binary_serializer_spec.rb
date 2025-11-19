# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "unibuf/serializers/flatbuffers/binary_serializer"
require "unibuf/parsers/flatbuffers/binary_parser"
require "unibuf/models/flatbuffers/schema"
require "unibuf/models/flatbuffers/table_definition"
require "unibuf/models/flatbuffers/field_definition"

RSpec.describe Unibuf::Serializers::Flatbuffers::BinarySerializer do
  # Helper to create a simple schema
  let(:simple_schema) do
    table_def = Unibuf::Models::Flatbuffers::TableDefinition.new(
      name: "Monster",
      fields: [
        Unibuf::Models::Flatbuffers::FieldDefinition.new(
          name: "hp",
          type: "int",
        ),
        Unibuf::Models::Flatbuffers::FieldDefinition.new(
          name: "name",
          type: "string",
        ),
      ],
    )

    Unibuf::Models::Flatbuffers::Schema.new(
      root_type: "Monster",
      tables: [table_def],
    )
  end

  let(:serializer) { described_class.new(simple_schema) }

  describe "initialization" do
    it "creates with schema" do
      expect(serializer.schema).to eq(simple_schema)
    end
  end

  describe "serialization validation" do
    it "raises on nil data" do
      expect do
        serializer.serialize(nil)
      end.to raise_error(ArgumentError, /nil/)
    end
  end

  describe "simple serialization" do
    it "serializes simple object" do
      data = {
        "hp" => 100,
        "name" => "Orc",
      }

      result = serializer.serialize(data)

      expect(result).to be_a(String)
      expect(result.encoding).to eq(Encoding::BINARY)
      expect(result).not_to be_empty
    end
  end

  describe "round-trip serialization" do
    it "round-trips simple data" do
      original_data = {
        "hp" => 150,
        "name" => "Dragon",
      }

      # Serialize
      binary_data = serializer.serialize(original_data)

      # Parse back
      parser = Unibuf::Parsers::Flatbuffers::BinaryParser.new(simple_schema)
      parsed_data = parser.parse(binary_data)

      # Verify
      expect(parsed_data["hp"]).to eq(150)
      expect(parsed_data["name"]).to eq("Dragon")
    end

    it "handles missing optional fields" do
      data = {
        "hp" => 50,
        # name is optional (not provided)
      }

      # Serialize
      binary_data = serializer.serialize(data)

      # Parse back
      parser = Unibuf::Parsers::Flatbuffers::BinaryParser.new(simple_schema)
      parsed_data = parser.parse(binary_data)

      # Verify
      expect(parsed_data["hp"]).to eq(50)
      expect(parsed_data["name"]).to be_nil
    end
  end

  describe "scalar types" do
    let(:scalar_schema) do
      table_def = Unibuf::Models::Flatbuffers::TableDefinition.new(
        name: "Test",
        fields: [
          Unibuf::Models::Flatbuffers::FieldDefinition.new(name: "byte_val", type: "byte"),
          Unibuf::Models::Flatbuffers::FieldDefinition.new(name: "ubyte_val", type: "ubyte"),
          Unibuf::Models::Flatbuffers::FieldDefinition.new(name: "short_val", type: "short"),
          Unibuf::Models::Flatbuffers::FieldDefinition.new(name: "int_val", type: "int"),
          Unibuf::Models::Flatbuffers::FieldDefinition.new(name: "float_val", type: "float"),
          Unibuf::Models::Flatbuffers::FieldDefinition.new(name: "bool_val", type: "bool"),
        ],
      )

      Unibuf::Models::Flatbuffers::Schema.new(
        root_type: "Test",
        tables: [table_def],
      )
    end

    it "round-trips all scalar types" do
      data = {
        "byte_val" => -42,
        "ubyte_val" => 200,
        "short_val" => -1000,
        "int_val" => 500000,
        "float_val" => 3.14,
        "bool_val" => true,
      }

      serializer_instance = described_class.new(scalar_schema)
      binary_data = serializer_instance.serialize(data)

      parser = Unibuf::Parsers::Flatbuffers::BinaryParser.new(scalar_schema)
      parsed_data = parser.parse(binary_data)

      expect(parsed_data["byte_val"]).to eq(-42)
      expect(parsed_data["ubyte_val"]).to eq(200)
      expect(parsed_data["short_val"]).to eq(-1000)
      expect(parsed_data["int_val"]).to eq(500000)
      expect(parsed_data["float_val"]).to be_within(0.01).of(3.14)
      expect(parsed_data["bool_val"]).to eq(true)
    end
  end

  describe "file operations" do
    let(:temp_dir) { Dir.mktmpdir }

    after do
      FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
    end

    it "writes and reads files" do
      data = {
        "hp" => 75,
        "name" => "Goblin",
      }

      file_path = File.join(temp_dir, "test.fb")

      # Serialize to file
      serializer.serialize_to_file(data, file_path)

      expect(File.exist?(file_path)).to be true

      # Parse from file
      parser = Unibuf::Parsers::Flatbuffers::BinaryParser.new(simple_schema)
      parsed_data = parser.parse_file(file_path)

      expect(parsed_data["hp"]).to eq(75)
      expect(parsed_data["name"]).to eq("Goblin")
    end
  end

  describe "error handling" do
    it "raises on invalid root type" do
      bad_schema = Unibuf::Models::Flatbuffers::Schema.new(
        root_type: "NonExistent",
        tables: [],
      )

      bad_serializer = described_class.new(bad_schema)

      expect do
        bad_serializer.serialize({})
      end.to raise_error(Unibuf::SerializationError, /Root type/)
    end
  end
end