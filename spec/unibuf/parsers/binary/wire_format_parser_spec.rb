# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Parsers::Binary::WireFormatParser do
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

  let(:parser) { described_class.new(schema) }

  describe "initialization" do
    it "creates with schema" do
      expect(parser.schema).to eq(schema)
    end
  end

  describe "varint parsing" do
    it "reads single-byte varint" do
      io = StringIO.new([0x00].pack("C"))
      io.set_encoding(Encoding::BINARY)
      expect(parser.send(:read_varint, io)).to eq(0)
    end

    it "reads multi-byte varint" do
      # 300 = 0xAC 0x02 in varint encoding
      io = StringIO.new([0xAC, 0x02].pack("C*"))
      io.set_encoding(Encoding::BINARY)
      expect(parser.send(:read_varint, io)).to eq(300)
    end

    it "handles maximum varint" do
      # Large number requiring multiple bytes
      io = StringIO.new([0xFF, 0xFF, 0xFF, 0xFF, 0x0F].pack("C*"))
      io.set_encoding(Encoding::BINARY)
      value = parser.send(:read_varint, io)
      expect(value).to be > 0
    end
  end

  describe "zigzag decoding" do
    it "decodes positive zigzag values" do
      expect(parser.send(:decode_zigzag_32, 0)).to eq(0)
      expect(parser.send(:decode_zigzag_32, 2)).to eq(1)
      expect(parser.send(:decode_zigzag_32, 4)).to eq(2)
    end

    it "decodes negative zigzag values" do
      expect(parser.send(:decode_zigzag_32, 1)).to eq(-1)
      expect(parser.send(:decode_zigzag_32, 3)).to eq(-2)
    end
  end

  describe "parsing with schema" do
    it "requires message type or single message schema" do
      expect do
        parser.parse("\x00")
      end.not_to raise_error
    end

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

  describe "wire type constants" do
    it "defines standard wire types" do
      expect(described_class::WIRE_TYPE_VARINT).to eq(0)
      expect(described_class::WIRE_TYPE_64BIT).to eq(1)
      expect(described_class::WIRE_TYPE_LENGTH_DELIMITED).to eq(2)
      expect(described_class::WIRE_TYPE_32BIT).to eq(5)
    end
  end

  describe "error handling" do
    it "handles malformed data gracefully" do
      expect do
        parser.parse("\xFF\xFF\xFF")
      end.to raise_error(Unibuf::ParseError)
    end
  end
end
