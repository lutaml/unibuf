# frozen_string_literal: true

require "spec_helper"
require "unibuf/models/capnproto/field_definition"

RSpec.describe Unibuf::Models::Capnproto::FieldDefinition do
  describe "initialization" do
    it "creates field with basic attributes" do
      field = described_class.new(
        name: "id",
        ordinal: 0,
        type: "UInt32",
      )

      expect(field.name).to eq("id")
      expect(field.ordinal).to eq(0)
      expect(field.type).to eq("UInt32")
    end

    it "creates field with default value" do
      field = described_class.new(
        name: "active",
        ordinal: 1,
        type: "Bool",
        default_value: true,
      )

      expect(field.default_value).to be true
    end
  end

  describe "type classification" do
    it "recognizes primitive types" do
      primitives = %w[Bool Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64
                      Float32 Float64 Void AnyPointer]

      primitives.each do |type|
        field = described_class.new(name: "test", ordinal: 0, type: type)
        expect(field.primitive_type?).to be true
      end
    end

    it "recognizes non-primitive types" do
      non_primitives = %w[Text Data Person Address]

      non_primitives.each do |type|
        field = described_class.new(name: "test", ordinal: 0, type: type)
        expect(field.primitive_type?).to be false
      end
    end

    it "recognizes generic list type" do
      field = described_class.new(
        name: "items",
        ordinal: 0,
        type: { generic: "List", element_type: "Int32" },
      )

      expect(field.generic_type?).to be true
      expect(field.list_type?).to be true
      expect(field.element_type).to eq("Int32")
    end

    it "recognizes user types" do
      field = described_class.new(
        name: "address",
        ordinal: 0,
        type: "Address",
      )

      expect(field.user_type?).to be true
      expect(field.primitive_type?).to be false
    end
  end

  describe "validation" do
    it "requires name" do
      field = described_class.new(ordinal: 0, type: "UInt32")

      expect(field.valid?).to be false
      expect do
        field.validate!
      end.to raise_error(Unibuf::ValidationError, /name required/)
    end

    it "requires ordinal" do
      field = described_class.new(name: "test", type: "UInt32")

      expect(field.valid?).to be false
      expect do
        field.validate!
      end.to raise_error(Unibuf::ValidationError, /ordinal required/)
    end

    it "requires type" do
      field = described_class.new(name: "test", ordinal: 0)

      expect(field.valid?).to be false
      expect do
        field.validate!
      end.to raise_error(Unibuf::ValidationError, /type required/)
    end

    it "rejects negative ordinals" do
      field = described_class.new(name: "test", ordinal: -1, type: "UInt32")

      expect(field.valid?).to be false
      expect do
        field.validate!
      end.to raise_error(Unibuf::ValidationError,
                         /must be non-negative/)
    end

    it "validates successfully with valid attributes" do
      field = described_class.new(
        name: "id",
        ordinal: 0,
        type: "UInt32",
      )

      expect(field.valid?).to be true
      expect { field.validate! }.not_to raise_error
    end
  end

  describe "to_h" do
    it "serializes to hash" do
      field = described_class.new(
        name: "id",
        ordinal: 0,
        type: "UInt32",
        default_value: 0,
      )

      hash = field.to_h

      expect(hash[:name]).to eq("id")
      expect(hash[:ordinal]).to eq(0)
      expect(hash[:type]).to eq("UInt32")
      expect(hash[:default_value]).to eq(0)
    end
  end
end
