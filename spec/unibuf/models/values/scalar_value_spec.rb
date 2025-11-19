# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Models::Values::ScalarValue do
  describe "type queries" do
    it "identifies string values" do
      value = described_class.new("hello")
      expect(value.scalar?).to be true
      expect(value.string?).to be true
      expect(value.integer?).to be false
      expect(value.float?).to be false
      expect(value.boolean?).to be false
    end

    it "identifies integer values" do
      value = described_class.new(42)
      expect(value.scalar?).to be true
      expect(value.integer?).to be true
      expect(value.string?).to be false
      expect(value.float?).to be false
    end

    it "identifies float values" do
      value = described_class.new(3.14)
      expect(value.scalar?).to be true
      expect(value.float?).to be true
      expect(value.integer?).to be false
    end

    it "identifies boolean values" do
      value_true = described_class.new(true)
      expect(value_true.boolean?).to be true

      value_false = described_class.new(false)
      expect(value_false.boolean?).to be true
    end

    it "identifies nil values" do
      value = described_class.new(nil)
      expect(value.nil?).to be true
    end
  end

  describe "type coercion" do
    it "converts any value to string" do
      expect(described_class.new(42).as_string).to eq("42")
      expect(described_class.new(3.14).as_string).to eq("3.14")
      expect(described_class.new(true).as_string).to eq("true")
      expect(described_class.new("hello").as_string).to eq("hello")
    end

    it "converts string to integer" do
      value = described_class.new("42")
      expect(value.as_integer).to eq(42)
    end

    it "keeps integer as integer" do
      value = described_class.new(42)
      expect(value.as_integer).to eq(42)
    end

    it "raises on invalid string to integer" do
      value = described_class.new("not a number")
      expect { value.as_integer }.to raise_error(Unibuf::TypeCoercionError)
    end

    it "converts to float" do
      expect(described_class.new(42).as_float).to eq(42.0)
      expect(described_class.new(3.14).as_float).to eq(3.14)
      expect(described_class.new("3.14").as_float).to eq(3.14)
    end

    it "raises on invalid float conversion" do
      value = described_class.new("not a number")
      expect { value.as_float }.to raise_error(Unibuf::TypeCoercionError)
    end

    it "converts to boolean" do
      expect(described_class.new(true).as_boolean).to be true
      expect(described_class.new(false).as_boolean).to be false
      expect(described_class.new("true").as_boolean).to be true
      expect(described_class.new("false").as_boolean).to be false
      expect(described_class.new("t").as_boolean).to be true
      expect(described_class.new("f").as_boolean).to be false
      expect(described_class.new(1).as_boolean).to be true
      expect(described_class.new(0).as_boolean).to be false
    end

    it "raises on invalid boolean conversion" do
      value = described_class.new("invalid")
      expect { value.as_boolean }.to raise_error(Unibuf::TypeCoercionError)
    end
  end

  describe "serialization" do
    it "serializes string values with quotes" do
      value = described_class.new("hello")
      expect(value.to_textproto).to eq('"hello"')
    end

    it "serializes integers" do
      value = described_class.new(42)
      expect(value.to_textproto).to eq("42")
    end

    it "serializes floats" do
      value = described_class.new(3.14)
      expect(value.to_textproto).to eq("3.14")
    end

    it "serializes booleans" do
      expect(described_class.new(true).to_textproto).to eq("true")
      expect(described_class.new(false).to_textproto).to eq("false")
    end

    it "serializes nil as empty string" do
      value = described_class.new(nil)
      expect(value.to_textproto).to eq('""')
    end

    it "escapes special characters" do
      value = described_class.new("line1\nline2")
      result = value.to_textproto
      expect(result).to include('\\n')

      value = described_class.new("tab\there")
      result = value.to_textproto
      expect(result).to include('\\t')
    end

    it "escapes backslashes and quotes" do
      value = described_class.new('back\\slash')
      result = value.to_textproto
      # One backslash becomes two in escaped form
      expect(result).to eq('"back\\slash"')

      value = described_class.new('quote"here')
      result = value.to_textproto
      expect(result).to include('\\"')
    end
  end

  describe "validation" do
    it "validates string type" do
      expect { described_class.new("test") }.not_to raise_error
    end

    it "validates integer type" do
      expect { described_class.new(42) }.not_to raise_error
    end

    it "validates float type" do
      expect { described_class.new(3.14) }.not_to raise_error
    end

    it "validates boolean types" do
      expect { described_class.new(true) }.not_to raise_error
      expect { described_class.new(false) }.not_to raise_error
    end

    it "validates nil" do
      expect { described_class.new(nil) }.not_to raise_error
    end

    it "rejects array" do
      expect { described_class.new([]) }.to raise_error(Unibuf::InvalidValueError)
    end

    it "rejects hash" do
      expect { described_class.new({}) }.to raise_error(Unibuf::InvalidValueError)
    end
  end

  describe "equality" do
    it "equals another scalar with same value" do
      value1 = described_class.new(42)
      value2 = described_class.new(42)
      expect(value1).to eq(value2)
    end

    it "not equals scalar with different value" do
      value1 = described_class.new(42)
      value2 = described_class.new(43)
      expect(value1).not_to eq(value2)
    end

    it "has consistent hash" do
      value1 = described_class.new("test")
      value2 = described_class.new("test")
      expect(value1.hash).to eq(value2.hash)
    end
  end
end