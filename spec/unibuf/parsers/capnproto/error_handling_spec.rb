# frozen_string_literal: true

require "spec_helper"
require "unibuf/models/capnproto/schema"
require "unibuf/models/capnproto/struct_definition"
require "unibuf/models/capnproto/field_definition"
require "unibuf/parsers/capnproto/grammar"
require "unibuf/parsers/capnproto/segment_reader"
require "unibuf/parsers/capnproto/pointer_decoder"
require "unibuf/parsers/capnproto/struct_reader"
require "unibuf/parsers/capnproto/binary_parser"
require "unibuf/serializers/capnproto/binary_serializer"

RSpec.describe "Cap'n Proto Error Handling" do
  describe "SegmentReader errors" do
    it "raises on invalid segment ID" do
      data = [0].pack("L<") + [1].pack("L<") + ("\x00" * 8)
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)

      expect do
        reader.read_word(5, 0)
      end.to raise_error(ArgumentError, /Invalid segment ID/)
    end

    it "raises on invalid word offset" do
      data = [0].pack("L<") + [1].pack("L<") + ("\x00" * 8)
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)

      expect do
        reader.read_word(0, -1)
      end.to raise_error(ArgumentError, /Invalid word offset/)
    end

    it "raises on offset out of bounds" do
      data = [0].pack("L<") + [1].pack("L<") + ("\x00" * 8)
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)

      expect do
        reader.read_word(0, 10)
      end.to raise_error(ArgumentError, /out of bounds/)
    end

    it "raises on invalid segment for read_bytes" do
      data = [0].pack("L<") + [1].pack("L<") + ("\x00" * 8)
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)

      expect do
        reader.read_bytes(5, 0,
                          8)
      end.to raise_error(ArgumentError, /Invalid segment ID/)
    end

    it "raises on bytes offset out of bounds" do
      data = [0].pack("L<") + [1].pack("L<") + ("\x00" * 8)
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)

      expect do
        reader.read_bytes(0, 100, 8)
      end.to raise_error(ArgumentError, /out of bounds/)
    end

    it "checks if segment exists" do
      data = [0].pack("L<") + [1].pack("L<") + ("\x00" * 8)
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)

      expect(reader.segment_exists?(0)).to be true
      expect(reader.segment_exists?(5)).to be false
      expect(reader.segment_exists?(-1)).to be false
    end

    it "handles empty data" do
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new("")

      expect(reader.segment_count).to eq(0)
    end

    it "handles nil data" do
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(nil)

      expect(reader.segment_count).to eq(0)
    end
  end

  describe "PointerDecoder edge cases" do
    it "decodes null pointer" do
      pointer = Unibuf::Parsers::Capnproto::PointerDecoder.decode(0)

      expect(pointer[:type]).to eq(:null)
      expect(pointer[:null]).to be true
    end

    it "checks if pointer is null" do
      expect(Unibuf::Parsers::Capnproto::PointerDecoder.null_pointer?(0)).to be true
      expect(Unibuf::Parsers::Capnproto::PointerDecoder.null_pointer?(1)).to be false
    end

    it "decodes capability pointer" do
      # Type = 3 (other/capability)
      word = 3 | (42 << 32)
      pointer = Unibuf::Parsers::Capnproto::PointerDecoder.decode(word)

      expect(pointer[:type]).to eq(:capability)
      expect(pointer[:index]).to eq(42)
    end

    it "decodes double-far pointer" do
      # Far pointer with double_far flag set
      word = 2 | (1 << 2) | (100 << 3) | (3 << 32)
      pointer = Unibuf::Parsers::Capnproto::PointerDecoder.decode(word)

      expect(pointer[:type]).to eq(:far)
      expect(pointer[:double_far]).to be true
      expect(pointer[:offset]).to eq(100)
    end
  end

  describe "BinaryParser errors" do
    it "raises when schema is nil" do
      expect do
        Unibuf::Parsers::Capnproto::BinaryParser.new(nil)
      end.not_to raise_error
    end

    it "raises on invalid root pointer" do
      schema = Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "Test",
            fields: [Unibuf::Models::Capnproto::FieldDefinition.new(name: "a",
                                                                    ordinal: 0, type: "UInt32")],
          ),
        ],
      )
      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(schema)

      # Create data with non-struct root pointer (list pointer)
      data = [0].pack("L<") + [1].pack("L<") +
        [1 | (1 << 2) | (1 << 32) | (10 << 35)].pack("Q<") # List pointer

      expect do
        parser.parse(data,
                     root_type: "Test")
      end.to raise_error(Unibuf::ParseError, /Invalid root pointer/)
    end

    it "raises when struct type not found" do
      schema = Unibuf::Models::Capnproto::Schema.new(file_id: "0x123",
                                                     structs: [])
      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(schema)

      data = [0].pack("L<") + [1].pack("L<") + [0 | (0 << 2) | (1 << 32)].pack("Q<")

      expect do
        parser.parse(data,
                     root_type: "NonExistent")
      end.to raise_error(Unibuf::ParseError, /not found/)
    end

    it "returns nil for null pointers" do
      schema = Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "Test",
            fields: [
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "text",
                                                             ordinal: 0, type: "Text"),
            ],
          ),
        ],
      )
      parser = Unibuf::Parsers::Capnproto::BinaryParser.new(schema)

      # Create struct with null pointer for text field
      data = [0].pack("L<") + [2].pack("L<") +
        [0 | (0 << 2) | (0 << 32) | (1 << 48)].pack("Q<") + # Root pointer to struct
        [0].pack("Q<") # Null pointer for text field

      result = parser.parse(data, root_type: "Test")
      expect(result[:text]).to be_nil
    end
  end

  describe "BinarySerializer errors" do
    it "raises when no root type specified" do
      schema = Unibuf::Models::Capnproto::Schema.new(file_id: "0x123",
                                                     structs: [])
      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(schema)

      expect do
        serializer.serialize({})
      end.to raise_error(Unibuf::SerializationError,
                         /No root type/)
    end

    it "raises when struct type not found" do
      schema = Unibuf::Models::Capnproto::Schema.new(file_id: "0x123",
                                                     structs: [])
      serializer = Unibuf::Serializers::Capnproto::BinarySerializer.new(schema)

      expect do
        serializer.serialize({},
                             root_type: "NonExistent")
      end.to raise_error(Unibuf::SerializationError, /not found/)
    end
  end

  describe "ListReader errors" do
    it "raises on index out of bounds for primitives" do
      data = [0].pack("L<") + [1].pack("L<") + [1, 2, 3, 4, 0, 0, 0,
                                                0].pack("C8")
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)
      list = Unibuf::Parsers::Capnproto::ListReader.new(reader, 0, 0, 2, 4)

      expect do
        list.read_primitive(10,
                            :uint8)
      end.to raise_error(ArgumentError, /out of bounds/)
    end

    it "raises on wrong list type for text" do
      data = [0].pack("L<") + [1].pack("L<") + [1, 2, 3, 4, 0, 0, 0,
                                                0].pack("C8")
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)
      list = Unibuf::Parsers::Capnproto::ListReader.new(reader, 0, 0, 5, 4)  # EIGHT_BYTES, not BYTE

      expect { list.read_text }.to raise_error(/Not a text list/)
    end

    it "raises on reading primitives from pointer list" do
      data = [0].pack("L<") + [1].pack("L<") + [0].pack("Q<")
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)
      list = Unibuf::Parsers::Capnproto::ListReader.new(reader, 0, 0, 6, 1)  # POINTER

      expect do
        list.read_primitive(0, :uint8)
      end.to raise_error(/Cannot read primitive/)
    end

    it "raises on reading pointers from non-pointer list" do
      data = [0].pack("L<") + [1].pack("L<") + [1, 2, 3, 4, 0, 0, 0,
                                                0].pack("C8")
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(data)
      list = Unibuf::Parsers::Capnproto::ListReader.new(reader, 0, 0, 2, 4)  # BYTE

      expect { list.read_pointer(0) }.to raise_error(/not pointers/)
    end
  end

  describe "Grammar parse errors" do
    let(:grammar) { Unibuf::Parsers::Capnproto::Grammar.new }

    it "raises on invalid syntax" do
      expect { grammar.parse("invalid capnp") }.to raise_error(Parslet::ParseFailed)
    end

    it "raises on incomplete struct" do
      expect { grammar.parse("struct Test {") }.to raise_error(Parslet::ParseFailed)
    end

    it "raises on invalid field" do
      expect { grammar.parse("struct Test { field }") }.to raise_error(Parslet::ParseFailed)
    end
  end
end
