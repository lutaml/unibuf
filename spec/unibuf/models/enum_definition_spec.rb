# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Models::EnumDefinition do
  describe "initialization" do
    it "creates with name and values" do
      enum_def = described_class.new(
        name: "Status",
        values: { "OK" => 0, "ERROR" => 1 },
      )

      expect(enum_def.name).to eq("Status")
      expect(enum_def.values.size).to eq(2)
    end

    it "handles empty values hash" do
      enum_def = described_class.new(
        name: "Empty",
        values: {},
      )

      expect(enum_def.values).to be_empty
    end
  end

  describe "queries" do
    let(:enum_def) do
      described_class.new(
        name: "Status",
        values: { "OK" => 0, "WARNING" => 1, "ERROR" => 2 },
      )
    end

    it "returns value names" do
      names = enum_def.value_names
      expect(names).to contain_exactly("OK", "WARNING", "ERROR")
    end

    it "returns value numbers" do
      numbers = enum_def.value_numbers
      expect(numbers).to contain_exactly(0, 1, 2)
    end

    it "finds value by name" do
      value = enum_def.find_value_by_name("ERROR")
      expect(value).to eq(2)
    end

    it "finds name by value" do
      name = enum_def.find_name_by_value(1)
      expect(name).to eq("WARNING")
    end

    it "returns nil for unknown name" do
      expect(enum_def.find_value_by_name("UNKNOWN")).to be_nil
    end

    it "returns nil for unknown value" do
      expect(enum_def.find_name_by_value(999)).to be_nil
    end
  end

  describe "validation" do
    it "validates successfully with name and values" do
      enum_def = described_class.new(
        name: "Status",
        values: { "OK" => 0 },
      )

      expect(enum_def.valid?).to be true
      expect { enum_def.validate! }.not_to raise_error
    end

    it "fails without name" do
      enum_def = described_class.new(
        values: { "OK" => 0 },
      )

      expect(enum_def.valid?).to be false
      expect do
        enum_def.validate!
      end.to raise_error(Unibuf::ValidationError, /name required/)
    end

    it "fails with empty values" do
      enum_def = described_class.new(
        name: "Empty",
        values: {},
      )

      expect do
        enum_def.validate!
      end.to raise_error(Unibuf::ValidationError,
                         /at least one value/)
    end

    it "detects duplicate values" do
      enum_def = described_class.new(
        name: "Bad",
        values: { "A" => 0, "B" => 0 },
      )

      expect do
        enum_def.validate!
      end.to raise_error(Unibuf::ValidationError, /Duplicate/)
    end
  end

  describe "value validation" do
    let(:enum_def) do
      described_class.new(
        name: "Status",
        values: { "OK" => 0, "ERROR" => 1 },
      )
    end

    it "validates string names" do
      expect(enum_def.valid_value?("OK")).to be true
      expect(enum_def.valid_value?("ERROR")).to be true
      expect(enum_def.valid_value?("UNKNOWN")).to be false
    end

    it "validates numeric values" do
      expect(enum_def.valid_value?(0)).to be true
      expect(enum_def.valid_value?(1)).to be true
      expect(enum_def.valid_value?(2)).to be false
    end

    it "rejects invalid types" do
      expect(enum_def.valid_value?(3.14)).to be false
      expect(enum_def.valid_value?([])).to be false
      expect(enum_def.valid_value?({})).to be false
    end
  end

  describe "transformation" do
    it "converts to hash" do
      enum_def = described_class.new(
        name: "Status",
        values: { "OK" => 0, "ERROR" => 1 },
      )

      hash = enum_def.to_h
      expect(hash[:name]).to eq("Status")
      expect(hash[:values]).to eq({ "OK" => 0, "ERROR" => 1 })
    end
  end
end
