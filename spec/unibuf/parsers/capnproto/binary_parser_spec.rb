# frozen_string_literal: true

require "spec_helper"
require "unibuf/parsers/capnproto/segment_reader"
require "unibuf/parsers/capnproto/pointer_decoder"
require "unibuf/parsers/capnproto/struct_reader"
require "unibuf/parsers/capnproto/list_reader"
require "unibuf/parsers/capnproto/binary_parser"

RSpec.describe "Cap'n Proto Binary Parsing" do
  describe Unibuf::Parsers::Capnproto::SegmentReader do
    describe "single segment" do
      it "parses segment count and size" do
        # Segment table: 1 segment (count-1 = 0), size = 2 words
        # With segment count = 1 (odd), NO padding after sizes
        data = [0].pack("L<") + # segment count - 1 = 0 (1 segment)
          [2].pack("L<") + # segment 0 size = 2 words
          # NO padding - header is 8 bytes, already aligned
          ("\x00" * 16) # 2 words of data

        reader = described_class.new(data)
        expect(reader.segment_count).to eq(1)
        expect(reader.segment_size(0)).to eq(2)
      end

      it "reads words from segment" do
        data = [0].pack("L<") + # count-1 = 0
          [1].pack("L<") + # size = 1 word
          # NO padding
          [0x1234567890ABCDEF].pack("Q<") # 1 word of data

        reader = described_class.new(data)
        word = reader.read_word(0, 0)
        expect(word).to eq(0x1234567890ABCDEF)
      end

      it "reads multiple words" do
        data = [0].pack("L<") + # count-1 = 0
          [2].pack("L<") + # size = 2 words
          # NO padding
          [0x1111111111111111, 0x2222222222222222].pack("Q<2")

        reader = described_class.new(data)
        words = reader.read_words(0, 0, 2)
        expect(words).to eq([0x1111111111111111, 0x2222222222222222])
      end
    end

    describe "multiple segments" do
      it "parses multiple segment sizes" do
        # 2 segments (count-1 = 1), sizes = 1 and 2 words
        # With segment count = 2 (even), NEEDS padding after sizes
        data = [1].pack("L<") + # count-1 = 1 (2 segments)
          [1, 2].pack("L<2") +  # sizes: 1 word, 2 words (8 bytes)
          [0].pack("L<") +      # padding to align to 16 bytes
          ("\x00" * 8) +          # Segment 0: 1 word
          ("\x00" * 16)           # Segment 1: 2 words

        reader = described_class.new(data)
        expect(reader.segment_count).to eq(2)
        expect(reader.segment_size(0)).to eq(1)
        expect(reader.segment_size(1)).to eq(2)
      end
    end
  end

  describe Unibuf::Parsers::Capnproto::PointerDecoder do
    it "decodes null pointer" do
      pointer = described_class.decode(0)
      expect(pointer[:type]).to eq(:null)
      expect(pointer[:null]).to be true
    end

    it "decodes struct pointer" do
      # Type = 0 (struct), offset = 1, data_size = 2, pointer_size = 1
      # Bits: [pointer_size:16][data_size:16][offset:30][type:2]
      word = 0 | # type: struct
        (1 << 2) | # offset: 1
        (2 << 32) | # data_size: 2
        (1 << 48)   # pointer_size: 1

      pointer = described_class.decode(word)
      expect(pointer[:type]).to eq(:struct)
      expect(pointer[:offset]).to eq(1)
      expect(pointer[:data_words]).to eq(2)
      expect(pointer[:pointer_words]).to eq(1)
    end

    it "decodes list pointer" do
      # Type = 1 (list), offset = 2, element_size = 5 (8-byte), count = 10
      word = 1 | # type: list
        (2 << 2) | # offset: 2
        (5 << 32) | # element_size: 8-byte
        (10 << 35)  # element_count: 10

      pointer = described_class.decode(word)
      expect(pointer[:type]).to eq(:list)
      expect(pointer[:offset]).to eq(2)
      expect(pointer[:element_size]).to eq(5)
      expect(pointer[:element_count]).to eq(10)
    end

    it "decodes far pointer" do
      # Type = 2 (far), segment_id = 3, offset = 100
      word = 2 | # type: far
        (100 << 3) | # offset: 100
        (3 << 32)    # segment_id: 3

      pointer = described_class.decode(word)
      expect(pointer[:type]).to eq(:far)
      expect(pointer[:segment_id]).to eq(3)
      expect(pointer[:offset]).to eq(100)
    end
  end

  describe Unibuf::Parsers::Capnproto::StructReader do
    let(:segment_data) do
      # Create a simple segment with struct data
      [0].pack("L<") +             # count-1 = 0
        [3].pack("L<") +           # size = 3 words
        # NO padding
        [42].pack("Q<") +          # data word 0: uint64 = 42
        [100].pack("Q<") +         # data word 1: uint64 = 100
        [0].pack("Q<")             # pointer word 0: null
    end

    let(:segment_reader) { Unibuf::Parsers::Capnproto::SegmentReader.new(segment_data) }
    let(:struct_reader) do
      described_class.new(segment_reader, 0, 0, 2, 1) # 2 data words, 1 pointer word
    end

    it "reads uint64 field" do
      value = struct_reader.read_uint64(0)
      expect(value).to eq(42)
    end

    it "reads uint32 field" do
      value = struct_reader.read_uint32(0, 0)
      expect(value).to eq(42)
    end

    it "reads bool field" do
      # Set bit 0 of word 0
      segment_data = [0].pack("L<") + [1].pack("L<") + [1].pack("Q<")
      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(segment_data)
      struct = described_class.new(reader, 0, 0, 1, 0)

      expect(struct.read_bool(0, 0)).to be true
      expect(struct.read_bool(0, 1)).to be false
    end
  end

  describe Unibuf::Parsers::Capnproto::ListReader do
    describe "primitive lists" do
      it "reads uint8 list" do
        # List of bytes: [1, 2, 3, 4]
        segment_data = [0].pack("L<") + # count-1 = 0
          [1].pack("L<") + # size = 1 word
          # NO padding
          [1, 2, 3, 4, 0, 0, 0, 0].pack("C8")

        reader = Unibuf::Parsers::Capnproto::SegmentReader.new(segment_data)
        list = described_class.new(reader, 0, 0, 2, 4) # ELEMENT_SIZE_BYTE, 4 elements

        expect(list.length).to eq(4)
        expect(list.read_primitive(0, :uint8)).to eq(1)
        expect(list.read_primitive(1, :uint8)).to eq(2)
        expect(list.read_primitive(2, :uint8)).to eq(3)
        expect(list.read_primitive(3, :uint8)).to eq(4)
      end

      it "reads text string" do
        # Text: "Hello" (with null terminator)
        text = "Hello\x00"
        padding = "\x00" * (8 - text.length)
        segment_data = [0].pack("L<") + # count-1 = 0
          [1].pack("L<") + # size = 1 word
          # NO padding
          text + padding

        reader = Unibuf::Parsers::Capnproto::SegmentReader.new(segment_data)
        list = described_class.new(reader, 0, 0, 2, 6) # ELEMENT_SIZE_BYTE, 6 bytes

        expect(list.read_text).to eq("Hello")
      end
    end
  end

  describe "Integration" do
    it "provides foundation for full binary parsing" do
      # This test verifies all components are properly integrated
      segment_data = [0].pack("L<") + # count-1 = 0
        [2].pack("L<") + # size = 2 words
        # NO padding
        [42].pack("Q<") +
        [0].pack("Q<")

      reader = Unibuf::Parsers::Capnproto::SegmentReader.new(segment_data)
      expect(reader.segment_count).to eq(1)

      struct_reader = Unibuf::Parsers::Capnproto::StructReader.new(reader, 0,
                                                                   0, 1, 1)
      expect(struct_reader.read_uint64(0)).to eq(42)
    end
  end
end
