# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Models::Values::MessageValue do
  describe "type identification" do
    it "identifies as message" do
      value = described_class.new("fields" => [])
      expect(value.message?).to be true
      expect(value.scalar?).to be false
      expect(value.list?).to be false
    end
  end

  describe "delegation to message" do
    let(:message_data) do
      {
        "fields" => [
          { "name" => "field1", "value" => "value1" },
          { "name" => "field2", "value" => 42 },
        ],
      }
    end

    let(:message_value) { described_class.new(message_data) }

    it "delegates fields" do
      expect(message_value.fields).to be_an(Array)
      expect(message_value.fields.size).to eq(2)
    end

    it "delegates field_count" do
      expect(message_value.field_count).to eq(2)
    end

    it "delegates find_field" do
      field = message_value.find_field("field1")
      expect(field).not_to be_nil
      expect(field.name).to eq("field1")
    end

    it "delegates field_names" do
      names = message_value.field_names
      expect(names).to contain_exactly("field1", "field2")
    end

    it "has message accessor" do
      expect(message_value.message).to be_a(Unibuf::Models::Message)
    end
  end

  describe "serialization" do
    it "serializes nested message" do
      message_data = {
        "fields" => [
          { "name" => "name", "value" => "test" },
        ],
      }

      message_value = described_class.new(message_data)
      result = message_value.to_textproto(indent: 0)

      expect(result).to include("{")
      expect(result).to include("}")
      expect(result).to include("name")
      expect(result).to include("test")
    end

    it "handles indentation" do
      message_data = { "fields" => [] }
      message_value = described_class.new(message_data)

      result = message_value.to_textproto(indent: 1)
      expect(result).to match(/\n  /)
    end
  end

  describe "validation" do
    it "validates hash with fields key" do
      expect { described_class.new("fields" => []) }.not_to raise_error
    end

    it "rejects hash without fields key" do
      expect do
        described_class.new("invalid" => "data")
      end.to raise_error(Unibuf::InvalidValueError, /fields/)
    end

    it "rejects non-hash" do
      expect { described_class.new("not hash") }.to raise_error(Unibuf::InvalidValueError)
      expect { described_class.new([]) }.to raise_error(Unibuf::InvalidValueError)
    end
  end

  describe "equality" do
    it "equals another message value with same fields" do
      data = { "fields" => [{ "name" => "test", "value" => "val" }] }
      value1 = described_class.new(data)
      value2 = described_class.new(data)
      expect(value1).to eq(value2)
    end

    it "not equals message value with different fields" do
      value1 = described_class.new("fields" => [{ "name" => "f1",
                                                  "value" => "v1" }])
      value2 = described_class.new("fields" => [{ "name" => "f2",
                                                  "value" => "v2" }])
      expect(value1).not_to eq(value2)
    end

    it "has consistent hash" do
      data = { "fields" => [{ "name" => "test", "value" => "val" }] }
      value1 = described_class.new(data)
      value2 = described_class.new(data)
      expect(value1.hash).to eq(value2.hash)
    end
  end
end
