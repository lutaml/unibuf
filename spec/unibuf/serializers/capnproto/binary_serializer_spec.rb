# frozen_string_literal: true

require "spec_helper"
require "unibuf/models/capnproto/schema"
require "unibuf/models/capnproto/struct_definition"
require "unibuf/models/capnproto/field_definition"
require "unibuf/serializers/capnproto/segment_builder"
require "unibuf/serializers/capnproto/pointer_encoder"
require "unibuf/serializers/capnproto/struct_writer"
require "unibuf/serializers/capnproto/list_writer"
require "unibuf/serializers/capnproto/binary_serializer"
require "unibuf/parsers/capnproto/segment_reader"
require "unibuf/parsers/capnproto/pointer_decoder"
require "unibuf/parsers/capnproto/binary_parser"

RSpec.describe "Cap'n Proto Binary Serialization" do
  describe Unibuf::Serializers::Capnproto::SegmentBuilder do
    let(:builder) { described_class.new }

    it "allocates words in segment" do
      segment_id, word_offset = builder.allocate(2)

      expect(segment_id).to eq(0)
      expect(word_offset).to eq(0)
    end

    it "writes words to segment" do
      builder.allocate(2)
      builder.write_word(0, 0, 0x1234567890ABCDEF)
      builder.write_word(0, 1, 0x1111111111111111)

      data = builder.build
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)

      expect(reader.read_word(0, 0)).to eq(0x1234567890ABCDEF)
      expect(reader.read_word(0, 1)).to eq(0x1111111111111111)
    end

    it "builds correct segment table for single segment" do
      builder.allocate(2)
      data = builder.build

      # Check segment count and size
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)
      expect(reader.segment_count).to eq(1)
      expect(reader.segment_size(0)).to eq(2)
    end
  end

  describe Unibuf::Serializers::Capnproto::PointerEncoder do
    it "encodes null pointer" do
      pointer = described_class.encode_null
      expect(pointer).to eq(0)
    end

    it "encodes struct pointer" do
      pointer = described_class.encode_struct(1, 2, 1)
      decoded = Unibuf::Parsers::Capnproto::PointerDecoder.decode(pointer)

      expect(decoded[:type]).to eq(:struct)
      expect(decoded[:offset]).to eq(1)
      expect(decoded[:data_words]).to eq(2)
      expect(decoded[:pointer_words]).to eq(1)
    end

    it "encodes list pointer" do
      pointer = described_class.encode_list(2, 5, 10)
      decoded = Unibuf::Parsers::Capnproto::PointerDecoder.decode(pointer)

      expect(decoded[:type]).to eq(:list)
      expect(decoded[:offset]).to eq(2)
      expect(decoded[:element_size]).to eq(5)
      expect(decoded[:element_count]).to eq(10)
    end

    it "encodes far pointer" do
      pointer = described_class.encode_far(3, 100)
      decoded = Unibuf::Parsers::Capnproto::PointerDecoder.decode(pointer)

      expect(decoded[:type]).to eq(:far)
      expect(decoded[:segment_id]).to eq(3)
      expect(decoded[:offset]).to eq(100)
    end

    it "determines correct element size for types" do
      expect(described_class.element_size_for_type("Bool")).to eq(1) # BIT
      expect(described_class.element_size_for_type("UInt8")).to eq(2) # BYTE
      expect(described_class.element_size_for_type("UInt16")).to eq(3) # TWO_BYTES
      expect(described_class.element_size_for_type("UInt32")).to eq(4) # FOUR_BYTES
      expect(described_class.element_size_for_type("UInt64")).to eq(5) # EIGHT_BYTES
    end
  end

  describe Unibuf::Serializers::Capnproto::StructWriter do
    let(:builder) { Unibuf::Serializers::Capnproto::SegmentBuilder.new }
    let(:struct_writer) do
      builder.allocate(3) # 2 data words, 1 pointer word
      described_class.new(builder, 0, 0, 2, 1)
    end

    it "writes uint64 field" do
      struct_writer.write_uint64(0, 42)

      data = builder.build
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)

      expect(reader.read_word(0, 0)).to eq(42)
    end

    it "writes uint32 field" do
      struct_writer.write_uint32(0, 0, 42)

      data = builder.build
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)
      word = reader.read_word(0, 0)

      expect(word & 0xFFFFFFFF).to eq(42)
    end

    it "writes bool field" do
      struct_writer.write_bool(0, 0, true)
      struct_writer.write_bool(0, 1, false)
      struct_writer.write_bool(0, 2, true)

      data = builder.build
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)
      word = reader.read_word(0, 0)

      expect((word >> 0) & 1).to eq(1) # bit 0 = true
      expect((word >> 1) & 1).to eq(0) # bit 1 = false
      expect((word >> 2) & 1).to eq(1) # bit 2 = true
    end
  end

  describe Unibuf::Serializers::Capnproto::ListWriter do
    let(:builder) { Unibuf::Serializers::Capnproto::SegmentBuilder.new }

    it "writes uint8 list" do
      builder.allocate(1) # 1 word for 4 bytes
      list_writer = described_class.new(builder, 0, 0, 2, 4) # ELEMENT_SIZE_BYTE, 4 elements

      list_writer.write_primitive(0, 1, :uint8)
      list_writer.write_primitive(1, 2, :uint8)
      list_writer.write_primitive(2, 3, :uint8)
      list_writer.write_primitive(3, 4, :uint8)

      data = builder.build
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)
      word = reader.read_word(0, 0)

      expect(word & 0xFF).to eq(1)
      expect((word >> 8) & 0xFF).to eq(2)
      expect((word >> 16) & 0xFF).to eq(3)
      expect((word >> 24) & 0xFF).to eq(4)
    end

    it "writes text" do
      text = "Hello"
      bytes_needed = text.length + 1 # with null terminator
      builder.allocate(1) # 1 word

      list_writer = described_class.new(builder, 0, 0, 2, bytes_needed)
      list_writer.write_text(text)

      data = builder.build
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)

      # Read bytes
      bytes = []
      bytes_needed.times do |i|
        word_idx = i / 8
        byte_idx = i % 8
        word = reader.read_word(0, word_idx)
        bytes << ((word >> (byte_idx * 8)) & 0xFF)
      end

      expect(bytes[0...-1].pack("C*")).to eq(text)
      expect(bytes[-1]).to eq(0) # null terminator
    end
  end

  describe "Round-trip serialization" do
    let(:fixture_path) do
      File.join(__dir__, "../../../fixtures/addressbook.capnp")
    end
    let(:schema) { Unibuf.parse_capnproto_schema(fixture_path) }

    it "can serialize and parse simple struct" do
      # Create simple data
      data = {
        id: 1,
        name: "Alice",
        email: "alice@example.com",
        phones: [],
      }

      # Serialize
      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(schema)
      binary = serializer.serialize(data, root_type: "Person")

      expect(binary).to be_a(String)
      expect(binary.length).to be > 0

      # Parse back
      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(schema)
      parsed = parser.parse(binary, root_type: "Person")

      expect(parsed[:id]).to eq(1)
      expect(parsed[:name]).to eq("Alice")
      expect(parsed[:email]).to eq("alice@example.com")
    end
  end

  describe "Integration with parser" do
    it "serializer output can be read by parser" do
      # Create a simple schema programmatically
      schema = Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123456",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "TestStruct",
            fields: [
              Unibuf::Models::Capnproto::FieldDefinition.new(
                name: "value",
                ordinal: 0,
                type: "UInt32",
              ),
            ],
          ),
        ],
      )

      data = { value: 42 }

      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(schema)
      binary = serializer.serialize(data, root_type: "TestStruct")

      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(schema)
      parsed = parser.parse(binary, root_type: "TestStruct")

      expect(parsed[:value]).to eq(42)
    end
  end
end
