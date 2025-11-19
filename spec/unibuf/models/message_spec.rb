# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Models::Message do
  describe "initialization" do
    it "creates a message with fields" do
      message = described_class.new(
        "fields" => [
          { "name" => "test", "value" => "hello" },
        ],
      )
      expect(message.field_count).to eq(1)
    end

    it "creates an empty message" do
      message = described_class.new
      expect(message.empty?).to be true
    end
  end

  describe "classification" do
    it "identifies nested messages" do
      message = described_class.new(
        "fields" => [
          { "name" => "nested", "value" => { "fields" => [] } },
        ],
      )
      expect(message.nested?).to be true
    end

    it "identifies scalar-only messages" do
      message = described_class.new(
        "fields" => [
          { "name" => "name", "value" => "test" },
          { "name" => "count", "value" => 42 },
        ],
      )
      expect(message.scalar_only?).to be true
      expect(message.nested?).to be false
    end

    it "identifies messages with maps" do
      message = described_class.new(
        "fields" => [
          {
            "name" => "mapping",
            "value" => { "key" => "k", "value" => "v" },
            "is_map" => true,
          },
        ],
      )
      expect(message.maps?).to be true
    end
  end

  describe "query methods" do
    let(:message) do
      described_class.new(
        "fields" => [
          { "name" => "name", "value" => "test" },
          { "name" => "count", "value" => 42 },
          { "name" => "name", "value" => "test2" },
        ],
      )
    end

    it "finds a field by name" do
      field = message.find_field("name")
      expect(field).not_to be_nil
      expect(field.name).to eq("name")
    end

    it "finds multiple fields with same name" do
      fields = message.find_fields("name")
      expect(fields.size).to eq(2)
    end

    it "returns field names" do
      expect(message.field_names).to contain_exactly("name", "count")
    end

    it "counts fields" do
      expect(message.field_count).to eq(3)
    end

    it "identifies repeated fields" do
      expect(message.repeated_fields?).to be true
      expect(message.repeated_field_names).to eq(["name"])
    end
  end

  describe "transformation" do
    let(:message) do
      described_class.new(
        "fields" => [
          { "name" => "test", "value" => "hello" },
        ],
      )
    end

    it "converts to hash" do
      hash = message.to_h
      expect(hash).to be_a(Hash)
      expect(hash["fields"]).to be_an(Array)
      expect(hash["fields"].first["name"]).to eq("test")
    end

    it "converts to JSON" do
      json = message.to_json
      expect(json).to be_a(String)
      expect(json).to include("test")
      expect(json).to include("hello")
    end

    it "converts to YAML" do
      yaml = message.to_yaml
      expect(yaml).to be_a(String)
      expect(yaml).to include("test")
      expect(yaml).to include("hello")
    end
  end

  describe "comparison" do
    it "equals another message with same fields" do
      message1 = described_class.new(
        "fields" => [{ "name" => "test", "value" => "hello" }],
      )
      message2 = described_class.new(
        "fields" => [{ "name" => "test", "value" => "hello" }],
      )
      expect(message1).to eq(message2)
    end

    it "not equals message with different fields" do
      message1 = described_class.new(
        "fields" => [{ "name" => "test", "value" => "hello" }],
      )
      message2 = described_class.new(
        "fields" => [{ "name" => "test", "value" => "world" }],
      )
      expect(message1).not_to eq(message2)
    end
  end
end
