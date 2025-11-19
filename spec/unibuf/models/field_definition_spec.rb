# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Models::FieldDefinition do
  describe "initialization" do
    it "creates with name, type, and number" do
      field_def = described_class.new(
        name: "test",
        type: "string",
        number: 1,
      )

      expect(field_def.name).to eq("test")
      expect(field_def.type).to eq("string")
      expect(field_def.number).to eq(1)
    end

    it "handles optional label" do
      field_def = described_class.new(
        name: "test",
        type: "int32",
        number: 1,
        label: "optional",
      )

      expect(field_def.label).to eq("optional")
      expect(field_def.optional?).to be true
    end

    it "handles repeated label" do
      field_def = described_class.new(
        name: "tags",
        type: "string",
        number: 1,
        label: "repeated",
      )

      expect(field_def.repeated?).to be true
    end

    it "handles map fields" do
      field_def = described_class.new(
        name: "mapping",
        type: "map",
        number: 1,
        key_type: "string",
        value_type: "int32",
      )

      expect(field_def.map?).to be true
      expect(field_def.key_type).to eq("string")
      expect(field_def.value_type).to eq("int32")
    end
  end

  describe "type queries" do
    it "identifies repeated fields" do
      field_def = described_class.new(
        name: "test",
        type: "string",
        number: 1,
        label: "repeated",
      )

      expect(field_def.repeated?).to be true
      expect(field_def.optional?).to be false
    end

    it "identifies optional fields" do
      field_def = described_class.new(
        name: "test",
        type: "string",
        number: 1,
        label: "optional",
      )

      expect(field_def.optional?).to be true
      expect(field_def.repeated?).to be false
    end

    it "treats nil label as optional" do
      field_def = described_class.new(
        name: "test",
        type: "string",
        number: 1,
      )

      expect(field_def.optional?).to be true
    end

    it "identifies scalar types" do
      %w[string int32 float bool].each do |type|
        field_def = described_class.new(
          name: "test",
          type: type,
          number: 1,
        )

        expect(field_def.scalar_type?).to be true
        expect(field_def.message_type?).to be false
      end
    end

    it "identifies message types" do
      field_def = described_class.new(
        name: "nested",
        type: "CustomMessage",
        number: 1,
      )

      expect(field_def.message_type?).to be true
      expect(field_def.scalar_type?).to be false
    end

    it "identifies map fields" do
      field_def = described_class.new(
        name: "map",
        type: "map",
        number: 1,
        key_type: "string",
        value_type: "int32",
      )

      expect(field_def.map?).to be true
      expect(field_def.scalar_type?).to be false
    end
  end

  describe "validation" do
    it "validates successfully with all required fields" do
      field_def = described_class.new(
        name: "test",
        type: "string",
        number: 1,
      )

      expect(field_def.valid?).to be true
      expect { field_def.validate! }.not_to raise_error
    end

    it "fails without name" do
      field_def = described_class.new(
        type: "string",
        number: 1,
      )

      expect(field_def.valid?).to be false
      expect do
        field_def.validate!
      end.to raise_error(Unibuf::ValidationError, /name required/)
    end

    it "fails without type" do
      field_def = described_class.new(
        name: "test",
        number: 1,
      )

      expect do
        field_def.validate!
      end.to raise_error(Unibuf::ValidationError, /type required/)
    end

    it "fails without number" do
      field_def = described_class.new(
        name: "test",
        type: "string",
      )

      expect do
        field_def.validate!
      end.to raise_error(Unibuf::ValidationError,
                         /number required/)
    end

    it "fails with non-positive number" do
      field_def = described_class.new(
        name: "test",
        type: "string",
        number: 0,
      )

      expect do
        field_def.validate!
      end.to raise_error(Unibuf::ValidationError,
                         /must be positive/)
    end
  end

  describe "value validation" do
    it "validates string values" do
      field_def = described_class.new(name: "test", type: "string", number: 1)

      expect(field_def.valid_value?("hello")).to be true
      expect(field_def.valid_value?(123)).to be false
    end

    it "validates int32 values" do
      field_def = described_class.new(name: "test", type: "int32", number: 1)

      expect(field_def.valid_value?(42)).to be true
      expect(field_def.valid_value?((2**31) - 1)).to be true
      expect(field_def.valid_value?(-2**31)).to be true
      expect(field_def.valid_value?(2**31)).to be false
      expect(field_def.valid_value?("string")).to be false
    end

    it "validates uint32 values" do
      field_def = described_class.new(name: "test", type: "uint32", number: 1)

      expect(field_def.valid_value?(42)).to be true
      expect(field_def.valid_value?(0)).to be true
      expect(field_def.valid_value?((2**32) - 1)).to be true
      expect(field_def.valid_value?(-1)).to be false
      expect(field_def.valid_value?(2**32)).to be false
    end

    it "validates float values" do
      field_def = described_class.new(name: "test", type: "float", number: 1)

      expect(field_def.valid_value?(3.14)).to be true
      expect(field_def.valid_value?(42)).to be true # Integers allowed
      expect(field_def.valid_value?("string")).to be false
    end

    it "validates bool values" do
      field_def = described_class.new(name: "test", type: "bool", number: 1)

      expect(field_def.valid_value?(true)).to be true
      expect(field_def.valid_value?(false)).to be true
      expect(field_def.valid_value?(1)).to be false
    end

    it "allows nil for optional fields" do
      field_def = described_class.new(
        name: "test",
        type: "string",
        number: 1,
        label: "optional",
      )

      expect(field_def.valid_value?(nil)).to be true
    end

    it "validates message types" do
      field_def = described_class.new(
        name: "nested",
        type: "CustomMessage",
        number: 1,
      )

      expect(field_def.valid_value?({})).to be true
      expect(field_def.valid_value?("string")).to be false
    end
  end

  describe "transformation" do
    it "converts to hash with all fields" do
      field_def = described_class.new(
        name: "test",
        type: "string",
        number: 1,
        label: "repeated",
      )

      hash = field_def.to_h
      expect(hash[:name]).to eq("test")
      expect(hash[:type]).to eq("string")
      expect(hash[:number]).to eq(1)
      expect(hash[:label]).to eq("repeated")
    end

    it "omits nil values from hash" do
      field_def = described_class.new(
        name: "test",
        type: "string",
        number: 1,
      )

      hash = field_def.to_h
      expect(hash).to have_key(:name)
      expect(hash).to have_key(:type)
      expect(hash).to have_key(:number)
      expect(hash).not_to have_key(:label)
    end

    it "includes map types in hash" do
      field_def = described_class.new(
        name: "map",
        type: "map",
        number: 1,
        key_type: "string",
        value_type: "int32",
      )

      hash = field_def.to_h
      expect(hash[:key_type]).to eq("string")
      expect(hash[:value_type]).to eq("int32")
    end
  end
end
