# frozen_string_literal: true

require "spec_helper"
require "unibuf/models/capnproto/enum_definition"

RSpec.describe Unibuf::Models::Capnproto::EnumDefinition do
  describe "initialization" do
    it "creates enum with name and values" do
      enum = described_class.new(
        name: "Color",
        values: { "red" => 0, "green" => 1, "blue" => 2 }
      )

      expect(enum.name).to eq("Color")
      expect(enum.values).to eq({ "red" => 0, "green" => 1, "blue" => 2 })
    end
  end

  describe "queries" do
    let(:enum_def) do
      described_class.new(
        name: "Color",
        values: { "red" => 0, "green" => 1, "blue" => 2 }
      )
    end

    it "returns value names" do
      expect(enum_def.value_names).to contain_exactly("red", "green", "blue")
    end

    it "returns ordinals" do
      expect(enum_def.ordinals).to contain_exactly(0, 1, 2)
    end

    it "finds value by name" do
      expect(enum_def.find_value("red")).to eq(0)
      expect(enum_def.find_value("green")).to eq(1)
    end

    it "finds name by ordinal" do
      expect(enum_def.find_name_by_ordinal(0)).to eq("red")
      expect(enum_def.find_name_by_ordinal(1)).to eq("green")
    end
  end

  describe "validation" do
    it "requires name" do
      enum = described_class.new(values: { "a" => 0 })

      expect(enum.valid?).to be false
      expect { enum.validate! }.to raise_error(Unibuf::ValidationError, /name required/)
    end

    it "requires at least one value" do
      enum = described_class.new(name: "Empty", values: {})

      expect(enum.valid?).to be false
      expect { enum.validate! }.to raise_error(Unibuf::ValidationError, /at least one value/)
    end

    it "detects duplicate ordinals" do
      enum = described_class.new(
        name: "Test",
        values: { "a" => 0, "b" => 0 }
      )

      expect(enum.valid?).to be false
      expect { enum.validate! }.to raise_error(Unibuf::ValidationError, /Duplicate ordinals/)
    end

    it "validates successfully" do
      enum = described_class.new(
        name: "Color",
        values: { "red" => 0, "green" => 1 }
      )

      expect(enum.valid?).to be true
      expect { enum.validate! }.not_to raise_error
    end
  end

  describe "to_h" do
    it "serializes to hash" do
      enum = described_class.new(
        name: "Color",
        values: { "red" => 0 },
        annotations: []
      )

      hash = enum.to_h

      expect(hash[:name]).to eq("Color")
      expect(hash[:values]).to eq({ "red" => 0 })
      expect(hash[:annotations]).to be_an(Array)
    end
  end
end