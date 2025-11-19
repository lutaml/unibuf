# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Models::Values::ListValue do
  describe "type identification" do
    it "identifies as list" do
      value = described_class.new([1, 2, 3])
      expect(value.list?).to be true
      expect(value.scalar?).to be false
      expect(value.message?).to be false
    end
  end

  describe "array-like interface" do
    let(:list) { described_class.new([1, 2, 3, 4, 5]) }

    it "returns size" do
      expect(list.size).to eq(5)
    end

    it "checks if empty" do
      expect(list.empty?).to be false
      expect(described_class.new([]).empty?).to be true
    end

    it "accesses by index" do
      expect(list[0]).to eq(1)
      expect(list[2]).to eq(3)
      expect(list[-1]).to eq(5)
    end

    it "returns first element" do
      expect(list.first).to eq(1)
    end

    it "returns last element" do
      expect(list.last).to eq(5)
    end

    it "supports each iteration" do
      result = []
      list.each { |item| result << item }
      expect(result).to eq([1, 2, 3, 4, 5])
    end

    it "supports map" do
      result = list.map { |item| item * 2 }
      expect(result).to eq([2, 4, 6, 8, 10])
    end

    it "supports select" do
      result = list.select { |item| item.even? }
      expect(result).to eq([2, 4])
    end
  end

  describe "type checking" do
    it "detects homogeneous lists" do
      list = described_class.new([1, 2, 3])
      expect(list.homogeneous?).to be true
    end

    it "detects heterogeneous lists" do
      list = described_class.new([1, "two", 3.0])
      expect(list.homogeneous?).to be false
    end

    it "treats empty list as homogeneous" do
      list = described_class.new([])
      expect(list.homogeneous?).to be true
    end

    it "detects all scalars" do
      list = described_class.new([1, "two", 3.14, true])
      expect(list.all_scalars?).to be true
    end

    it "detects all messages" do
      list = described_class.new([
        { "fields" => [] },
        { "fields" => [] }
      ])
      expect(list.all_messages?).to be true
    end

    it "detects mixed types" do
      list = described_class.new([1, { "fields" => [] }])
      expect(list.all_scalars?).to be false
      expect(list.all_messages?).to be false
    end
  end

  describe "serialization" do
    it "serializes small scalar lists inline" do
      list = described_class.new([1, 2, 3])
      result = list.to_textproto
      expect(result).to match(/^\[.*\]$/)
      expect(result).to include("1")
      expect(result).to include("2")
      expect(result).to include("3")
    end

    it "serializes empty list" do
      list = described_class.new([])
      expect(list.to_textproto).to eq("[]")
    end

    it "serializes string lists" do
      list = described_class.new(["a", "b", "c"])
      result = list.to_textproto
      expect(result).to include('"a"')
      expect(result).to include('"b"')
      expect(result).to include('"c"')
    end

    it "serializes boolean lists" do
      list = described_class.new([true, false, true])
      result = list.to_textproto
      expect(result).to include("true")
      expect(result).to include("false")
    end
  end

  describe "validation" do
    it "validates array type" do
      expect { described_class.new([]) }.not_to raise_error
      expect { described_class.new([1, 2, 3]) }.not_to raise_error
    end

    it "rejects non-array" do
      expect { described_class.new("not array") }.to raise_error(Unibuf::InvalidValueError)
      expect { described_class.new(42) }.to raise_error(Unibuf::InvalidValueError)
      expect { described_class.new({}) }.to raise_error(Unibuf::InvalidValueError)
    end
  end

  describe "equality" do
    it "equals another list with same values" do
      list1 = described_class.new([1, 2, 3])
      list2 = described_class.new([1, 2, 3])
      expect(list1).to eq(list2)
    end

    it "not equals list with different values" do
      list1 = described_class.new([1, 2, 3])
      list2 = described_class.new([1, 2, 4])
      expect(list1).not_to eq(list2)
    end
  end
end