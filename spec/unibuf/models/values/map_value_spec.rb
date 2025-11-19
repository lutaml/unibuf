# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Models::Values::MapValue do
  describe "type identification" do
    it "identifies as map" do
      value = described_class.new("key" => "k", "value" => "v")
      expect(value.map?).to be true
      expect(value.scalar?).to be false
      expect(value.list?).to be false
    end
  end

  describe "hash-like interface" do
    let(:map) { described_class.new("key" => "name", "value" => "test") }

    it "returns key" do
      expect(map.key).to eq("name")
    end

    it "returns value" do
      expect(map.value).to eq("test")
    end

    it "converts to hash" do
      hash = map.to_h
      expect(hash).to eq({ "name" => "test" })
    end
  end

  describe "type checking" do
    it "detects key type" do
      map = described_class.new("key" => "string_key", "value" => 42)
      expect(map.key_type).to eq(String)
    end

    it "detects value type" do
      map = described_class.new("key" => "k", "value" => 42)
      expect(map.value_type).to eq(Integer)
    end

    it "identifies scalar values" do
      map = described_class.new("key" => "k", "value" => "scalar")
      expect(map.scalar_value?).to be true
    end

    it "identifies message values" do
      map = described_class.new("key" => "k", "value" => { "fields" => [] })
      expect(map.message_value?).to be true
      expect(map.scalar_value?).to be false
    end
  end

  describe "serialization" do
    it "serializes string key-value pairs" do
      map = described_class.new("key" => "name", "value" => "test")
      result = map.to_textproto
      expect(result).to include("key:")
      expect(result).to include("value:")
      expect(result).to include('"name"')
      expect(result).to include('"test"')
    end

    it "serializes numeric values" do
      map = described_class.new("key" => "count", "value" => 42)
      result = map.to_textproto
      expect(result).to include("42")
    end

    it "serializes boolean values" do
      map = described_class.new("key" => "enabled", "value" => true)
      result = map.to_textproto
      expect(result).to include("true")
    end

    it "uses proper indentation" do
      map = described_class.new("key" => "k", "value" => "v")
      result = map.to_textproto(indent: 1)
      expect(result).to match(/\n  /)
    end
  end

  describe "validation" do
    it "validates hash with key and value" do
      expect {
        described_class.new("key" => "k", "value" => "v")
      }.not_to raise_error
    end

    it "rejects non-hash" do
      expect { described_class.new("not a hash") }.to raise_error(Unibuf::InvalidValueError)
      expect { described_class.new([]) }.to raise_error(Unibuf::InvalidValueError)
    end

    it "rejects hash without key" do
      expect {
        described_class.new("value" => "v")
      }.to raise_error(Unibuf::InvalidValueError, /key/)
    end

    it "rejects hash without value" do
      expect {
        described_class.new("key" => "k")
      }.to raise_error(Unibuf::InvalidValueError, /value/)
    end
  end

  describe "equality" do
    it "equals another map with same key-value" do
      map1 = described_class.new("key" => "k", "value" => "v")
      map2 = described_class.new("key" => "k", "value" => "v")
      expect(map1).to eq(map2)
    end

    it "not equals map with different key" do
      map1 = described_class.new("key" => "k1", "value" => "v")
      map2 = described_class.new("key" => "k2", "value" => "v")
      expect(map1).not_to eq(map2)
    end

    it "not equals map with different value" do
      map1 = described_class.new("key" => "k", "value" => "v1")
      map2 = described_class.new("key" => "k", "value" => "v2")
      expect(map1).not_to eq(map2)
    end

    it "has consistent hash" do
      map1 = described_class.new("key" => "k", "value" => "v")
      map2 = described_class.new("key" => "k", "value" => "v")
      expect(map1.hash).to eq(map2.hash)
    end
  end
end