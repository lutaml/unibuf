# frozen_string_literal: true

require "spec_helper"
require "unibuf/parsers/flatbuffers/binary_parser"
require "unibuf/models/flatbuffers/schema"
require "unibuf/models/flatbuffers/table_definition"
require "unibuf/models/flatbuffers/field_definition"

RSpec.describe Unibuf::Parsers::Flatbuffers::BinaryParser do
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

  let(:parser) { described_class.new(simple_schema) }

  describe "initialization" do
    it "creates with schema" do
      expect(parser.schema).to eq(simple_schema)
    end
  end

  describe "parsing validation" do
    it "raises on nil data" do
      expect do
        parser.parse(nil)
      end.to raise_error(ArgumentError, /nil/)
    end

    it "raises on empty data" do
      expect do
        parser.parse("")
      end.to raise_error(ArgumentError, /empty/)
    end
  end

  describe "scalar reading" do
    it "reads int8" do
      data = [42].pack("c")
      io = StringIO.new(data)
      io.set_encoding(Encoding::BINARY)
      parser.instance_variable_set(:@io, io)

      result = parser.send(:read_int8, 0)
      expect(result).to eq(42)
    end

    it "reads uint32" do
      data = [300].pack("L<")
      io = StringIO.new(data)
      io.set_encoding(Encoding::BINARY)
      parser.instance_variable_set(:@io, io)

      result = parser.send(:read_uint32, 0)
      expect(result).to eq(300)
    end

    it "reads float" do
      data = [3.14].pack("e")
      io = StringIO.new(data)
      io.set_encoding(Encoding::BINARY)
      parser.instance_variable_set(:@io, io)

      result = parser.send(:read_float, 0)
      expect(result).to be_within(0.01).of(3.14)
    end

    it "reads bool as true" do
      data = [1].pack("C")
      io = StringIO.new(data)
      io.set_encoding(Encoding::BINARY)
      parser.instance_variable_set(:@io, io)

      result = parser.send(:read_scalar, 0, "bool")
      expect(result).to eq(true)
    end

    it "reads bool as false" do
      data = [0].pack("C")
      io = StringIO.new(data)
      io.set_encoding(Encoding::BINARY)
      parser.instance_variable_set(:@io, io)

      result = parser.send(:read_scalar, 0, "bool")
      expect(result).to eq(false)
    end
  end

  describe "element size" do
    it "returns correct sizes for scalar types" do
      expect(parser.send(:element_size, "byte")).to eq(1)
      expect(parser.send(:element_size, "ubyte")).to eq(1)
      expect(parser.send(:element_size, "short")).to eq(2)
      expect(parser.send(:element_size, "int")).to eq(4)
      expect(parser.send(:element_size, "long")).to eq(8)
      expect(parser.send(:element_size, "float")).to eq(4)
      expect(parser.send(:element_size, "double")).to eq(8)
    end
  end

  describe "schema integration" do
    it "finds root table in schema" do
      expect(simple_schema.root_type).to eq("Monster")
      expect(simple_schema.find_table("Monster")).not_to be_nil
    end
  end

  describe "error handling" do
    it "raises on missing root type in schema" do
      bad_schema = Unibuf::Models::Flatbuffers::Schema.new(
        root_type: "Unknown",
        tables: [],
      )

      bad_parser = described_class.new(bad_schema)

      # Create minimal binary data (just root offset)
      data = [4].pack("L<")

      expect do
        bad_parser.parse(data)
      end.to raise_error(Unibuf::ParseError, /Root type/)
    end
  end
end