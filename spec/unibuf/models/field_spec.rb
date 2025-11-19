# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Models::Field do
  describe "initialization" do
    it "creates a field with name and value" do
      field = described_class.new("name" => "test", "value" => "hello")
      expect(field.name).to eq("test")
      expect(field.value).to eq("hello")
    end

    it "defaults is_map to false" do
      field = described_class.new("name" => "test", "value" => "hello")
      expect(field.is_map).to be(false)
    end
  end

  describe "type queries" do
    it "identifies scalar fields" do
      field = described_class.new("name" => "test", "value" => "hello")
      expect(field.scalar_field?).to be true
      expect(field.message_field?).to be false
      expect(field.map_field?).to be false
      expect(field.list_field?).to be false
    end

    it "identifies message fields" do
      field = described_class.new("name" => "nested",
                                  "value" => { "fields" => [] })
      expect(field.message_field?).to be true
      expect(field.scalar_field?).to be false
    end

    it "identifies map fields" do
      field = described_class.new(
        "name" => "mapping",
        "value" => { "key" => "k", "value" => "v" },
        "is_map" => true,
      )
      expect(field.map_field?).to be true
      expect(field.scalar_field?).to be false
    end

    it "identifies list fields" do
      field = described_class.new("name" => "items", "value" => [1, 2, 3])
      expect(field.list_field?).to be true
      expect(field.scalar_field?).to be false
    end
  end

  describe "value type detection" do
    it "detects string values" do
      field = described_class.new("name" => "str", "value" => "hello")
      expect(field.string_value?).to be true
      expect(field.integer_value?).to be false
    end

    it "detects integer values" do
      field = described_class.new("name" => "num", "value" => 42)
      expect(field.integer_value?).to be true
      expect(field.string_value?).to be false
    end

    it "detects float values" do
      field = described_class.new("name" => "pi", "value" => 3.14)
      expect(field.float_value?).to be true
      expect(field.integer_value?).to be false
    end

    it "detects boolean values" do
      field = described_class.new("name" => "flag", "value" => true)
      expect(field.boolean_value?).to be true
    end
  end

  describe "value accessors" do
    it "converts to string" do
      field = described_class.new("name" => "test", "value" => "hello")
      expect(field.as_string).to eq("hello")
    end

    it "converts to integer" do
      field = described_class.new("name" => "count", "value" => 42)
      expect(field.as_integer).to eq(42)
    end

    it "raises on invalid conversion" do
      field = described_class.new("name" => "test",
                                  "value" => { "fields" => [] })
      expect { field.as_integer }.to raise_error(Unibuf::TypeCoercionError)
    end
  end

  describe "comparison" do
    it "equals another field with same name and value" do
      field1 = described_class.new("name" => "test", "value" => "hello")
      field2 = described_class.new("name" => "test", "value" => "hello")
      expect(field1).to eq(field2)
    end

    it "not equals field with different value" do
      field1 = described_class.new("name" => "test", "value" => "hello")
      field2 = described_class.new("name" => "test", "value" => "world")
      expect(field1).not_to eq(field2)
    end
  end
end
