# frozen_string_literal: true

require "spec_helper"
require "unibuf/models/capnproto/union_definition"
require "unibuf/models/capnproto/field_definition"
require "unibuf/parsers/capnproto/binary_parser"
require "unibuf/serializers/capnproto/binary_serializer"

RSpec.describe "Cap'n Proto Comprehensive Coverage" do
  describe Unibuf::Models::Capnproto::UnionDefinition do
    describe "initialization" do
      it "creates union with fields" do
        field = Unibuf::Models::Capnproto::FieldDefinition.new(
          name: "text",
          ordinal: 0,
          type: "Text"
        )
        union = described_class.new(fields: [field])

        expect(union.fields.length).to eq(1)
      end
    end

    describe "queries" do
      let(:field1) do
        Unibuf::Models::Capnproto::FieldDefinition.new(
          name: "text",
          ordinal: 0,
          type: "Text"
        )
      end

      let(:field2) do
        Unibuf::Models::Capnproto::FieldDefinition.new(
          name: "number",
          ordinal: 1,
          type: "Int32"
        )
      end

      let(:union_def) { described_class.new(fields: [field1, field2]) }

      it "returns field names" do
        expect(union_def.field_names).to eq(["text", "number"])
      end

      it "returns ordinals" do
        expect(union_def.ordinals).to eq([0, 1])
      end

      it "finds field by name" do
        expect(union_def.find_field("text")).to eq(field1)
      end
    end

    describe "validation" do
      it "requires at least two fields" do
        field = Unibuf::Models::Capnproto::FieldDefinition.new(
          name: "only",
          ordinal: 0,
          type: "Text"
        )
        union = described_class.new(fields: [field])

        expect(union.valid?).to be false
        expect { union.validate! }.to raise_error(Unibuf::ValidationError, /at least two fields/)
      end

      it "detects duplicate ordinals" do
        field1 = Unibuf::Models::Capnproto::FieldDefinition.new(name: "a", ordinal: 0, type: "Text")
        field2 = Unibuf::Models::Capnproto::FieldDefinition.new(name: "b", ordinal: 0, type: "Int32")
        union = described_class.new(fields: [field1, field2])

        expect(union.valid?).to be false
        expect { union.validate! }.to raise_error(Unibuf::ValidationError, /Duplicate ordinals/)
      end

      it "validates successfully" do
        field1 = Unibuf::Models::Capnproto::FieldDefinition.new(name: "text", ordinal: 0, type: "Text")
        field2 = Unibuf::Models::Capnproto::FieldDefinition.new(name: "number", ordinal: 1, type: "Int32")
        union = described_class.new(fields: [field1, field2])

        expect(union.valid?).to be true
        expect { union.validate! }.not_to raise_error
      end
    end

    describe "to_h" do
      it "serializes to hash" do
        field = Unibuf::Models::Capnproto::FieldDefinition.new(name: "a", ordinal: 0, type: "Text")
        union = described_class.new(fields: [field])

        hash = union.to_h
        expect(hash[:fields]).to be_an(Array)
      end
    end
  end

  describe "BinaryParser helper methods" do
    let(:schema) do
      Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "Test",
            fields: [
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "id", ordinal: 0, type: "UInt32"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "name", ordinal: 1, type: "Text"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "data", ordinal: 2, type: "Data")
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
    end

    let(:parser) { Unibuf::Parsers::Capnproto::BinaryParser.new(schema) }

    it "checks if type is primitive" do
      expect(parser.send(:primitive_type?, "UInt32")).to be true
      expect(parser.send(:primitive_type?, "Text")).to be false
      expect(parser.send(:primitive_type?, "Person")).to be false
    end

    it "converts type to symbol" do
      expect(parser.send(:type_to_symbol, "Int8")).to eq(:int8)
      expect(parser.send(:type_to_symbol, "UInt32")).to eq(:uint32)
      expect(parser.send(:type_to_symbol, "Float64")).to eq(:float64)
      expect(parser.send(:type_to_symbol, "Bool")).to eq(:bool)
    end

    it "checks text_or_data_type" do
      field_text = Unibuf::Models::Capnproto::FieldDefinition.new(name: "t", ordinal: 0, type: "Text")
      field_data = Unibuf::Models::Capnproto::FieldDefinition.new(name: "d", ordinal: 1, type: "Data")
      field_int = Unibuf::Models::Capnproto::FieldDefinition.new(name: "i", ordinal: 2, type: "Int32")

      expect(parser.send(:text_or_data_type?, field_text)).to be true
      expect(parser.send(:text_or_data_type?, field_data)).to be true
      expect(parser.send(:text_or_data_type?, field_int)).to be false
    end
  end

  describe "BinarySerializer helper methods" do
    let(:schema) do
      Unibuf::Models::Capnproto::Schema.new(
        file_id: "0x123",
        structs: [
          Unibuf::Models::Capnproto::StructDefinition.new(
            name: "Test",
            fields: [
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "a", ordinal: 0, type: "UInt8"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "b", ordinal: 1, type: "UInt16"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "c", ordinal: 2, type: "UInt32"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "d", ordinal: 3, type: "UInt64"),
              Unibuf::Models::Capnproto::FieldDefinition.new(name: "text", ordinal: 0, type: "Text")
            ]
          )
        ]
      )
    end

    let(:serializer) { Unibuf::Serializers::Capnproto::BinarySerializer.new(schema) }

    it "calculates data words for various types" do
      struct_def = schema.find_struct("Test")
      data_words = serializer.send(:calculate_data_words, struct_def)

      expect(data_words).to be > 0
    end

    it "calculates pointer words" do
      struct_def = schema.find_struct("Test")
      pointer_words = serializer.send(:calculate_pointer_words, struct_def)

      expect(pointer_words).to eq(1)  # Only "text" is a pointer
    end

    it "calculates list words for different element sizes" do
      # VOID
      expect(serializer.send(:calculate_list_words, 0, 10)).to eq(0)
      # BIT
      expect(serializer.send(:calculate_list_words, 1, 65)).to eq(2)
      # BYTE
      expect(serializer.send(:calculate_list_words, 2, 10)).to eq(2)
      # TWO_BYTES
      expect(serializer.send(:calculate_list_words, 3, 5)).to eq(2)
      # FOUR_BYTES
      expect(serializer.send(:calculate_list_words, 4, 3)).to eq(2)
      # EIGHT_BYTES
      expect(serializer.send(:calculate_list_words, 5, 3)).to eq(3)
    end

    it "gets pointer index for field" do
      struct_def = schema.find_struct("Test")
      text_field = struct_def.find_field("text")

      pointer_index = serializer.send(:get_pointer_index, text_field, struct_def)
      expect(pointer_index).to eq(0)
    end
  end

  describe "Additional type classifications" do
    it "classifies all primitive types correctly" do
      types = %w[Void Bool Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64 Float32 Float64 AnyPointer]

      types.each do |type|
        field = Unibuf::Models::Capnproto::FieldDefinition.new(
          name: "test",
          ordinal: 0,
          type: type
        )
        expect(field.primitive_type?).to be true
        expect(field.user_type?).to be false
      end
    end

    it "classifies Text and Data as non-primitive" do
      ["Text", "Data"].each do |type|
        field = Unibuf::Models::Capnproto::FieldDefinition.new(
          name: "test",
          ordinal: 0,
          type: type
        )
        expect(field.primitive_type?).to be false
        expect(field.user_type?).to be true
      end
    end

    it "classifies generic types" do
      field = Unibuf::Models::Capnproto::FieldDefinition.new(
        name: "items",
        ordinal: 0,
        type: { generic: "List", element_type: "UInt32" }
      )

      expect(field.generic_type?).to be true
      expect(field.list_type?).to be true
      expect(field.primitive_type?).to be false
      expect(field.user_type?).to be false
    end
  end
end