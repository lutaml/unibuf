# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Models::MessageDefinition do
  describe "initialization" do
    it "creates with name and fields" do
      field = Unibuf::Models::FieldDefinition.new(
        name: "test",
        type: "string",
        number: 1,
      )

      msg_def = described_class.new(
        name: "TestMessage",
        fields: [field],
      )

      expect(msg_def.name).to eq("TestMessage")
      expect(msg_def.fields.size).to eq(1)
    end

    it "handles nested messages" do
      nested = described_class.new(name: "Nested", fields: [])

      msg_def = described_class.new(
        name: "Parent",
        fields: [],
        nested_messages: [nested],
      )

      expect(msg_def.nested_messages.size).to eq(1)
      expect(msg_def.has_nested_messages?).to be true
    end

    it "handles nested enums" do
      enum = Unibuf::Models::EnumDefinition.new(
        name: "Status",
        values: { "OK" => 0, "ERROR" => 1 },
      )

      msg_def = described_class.new(
        name: "Response",
        fields: [],
        nested_enums: [enum],
      )

      expect(msg_def.nested_enums.size).to eq(1)
    end
  end

  describe "queries" do
    let(:field1) do
      Unibuf::Models::FieldDefinition.new(
        name: "name",
        type: "string",
        number: 1,
      )
    end

    let(:field2) do
      Unibuf::Models::FieldDefinition.new(
        name: "count",
        type: "int32",
        number: 2,
      )
    end

    let(:msg_def) do
      described_class.new(
        name: "TestMessage",
        fields: [field1, field2],
      )
    end

    it "finds field by name" do
      field = msg_def.find_field("name")
      expect(field).not_to be_nil
      expect(field.name).to eq("name")
      expect(field.type).to eq("string")
    end

    it "finds field by number" do
      field = msg_def.find_field_by_number(2)
      expect(field).not_to be_nil
      expect(field.name).to eq("count")
    end

    it "returns nil for unknown field" do
      expect(msg_def.find_field("unknown")).to be_nil
      expect(msg_def.find_field_by_number(999)).to be_nil
    end

    it "returns field names" do
      names = msg_def.field_names
      expect(names).to contain_exactly("name", "count")
    end

    it "returns field numbers" do
      numbers = msg_def.field_numbers
      expect(numbers).to contain_exactly(1, 2)
    end
  end

  describe "classification" do
    it "identifies messages with repeated fields" do
      repeated_field = Unibuf::Models::FieldDefinition.new(
        name: "tags",
        type: "string",
        number: 1,
        label: "repeated",
      )

      msg_def = described_class.new(
        name: "Test",
        fields: [repeated_field],
      )

      expect(msg_def.has_repeated_fields?).to be true
    end

    it "identifies messages with maps" do
      map_field = Unibuf::Models::FieldDefinition.new(
        name: "mapping",
        type: "map",
        number: 1,
        key_type: "string",
        value_type: "int32",
      )

      msg_def = described_class.new(
        name: "Test",
        fields: [map_field],
      )

      expect(msg_def.has_maps?).to be true
    end
  end

  describe "validation" do
    it "validates successfully with valid definition" do
      field = Unibuf::Models::FieldDefinition.new(
        name: "test",
        type: "string",
        number: 1,
      )

      msg_def = described_class.new(
        name: "Valid",
        fields: [field],
      )

      expect(msg_def.valid?).to be true
      expect { msg_def.validate! }.not_to raise_error
    end

    it "fails validation without name" do
      msg_def = described_class.new(fields: [])

      expect(msg_def.valid?).to be false
      expect do
        msg_def.validate!
      end.to raise_error(Unibuf::ValidationError, /name required/)
    end

    it "detects duplicate field numbers" do
      field1 = Unibuf::Models::FieldDefinition.new(name: "f1", type: "string",
                                                   number: 1)
      field2 = Unibuf::Models::FieldDefinition.new(name: "f2", type: "int32",
                                                   number: 1)

      msg_def = described_class.new(
        name: "Test",
        fields: [field1, field2],
      )

      expect do
        msg_def.validate!
      end.to raise_error(Unibuf::ValidationError,
                         /Duplicate field numbers/)
    end

    it "validates field values" do
      field = Unibuf::Models::FieldDefinition.new(
        name: "name",
        type: "string",
        number: 1,
      )

      msg_def = described_class.new(
        name: "Test",
        fields: [field],
      )

      expect(msg_def.valid_field_value?("name", "hello")).to be true
      expect(msg_def.valid_field_value?("name", 123)).to be false
      expect(msg_def.valid_field_value?("unknown", "value")).to be false
    end
  end

  describe "transformation" do
    it "converts to hash" do
      field = Unibuf::Models::FieldDefinition.new(
        name: "test",
        type: "string",
        number: 1,
      )

      msg_def = described_class.new(
        name: "TestMessage",
        fields: [field],
      )

      hash = msg_def.to_h
      expect(hash).to be_a(Hash)
      expect(hash[:name]).to eq("TestMessage")
      expect(hash[:fields]).to be_an(Array)
      expect(hash[:fields].size).to eq(1)
    end
  end
end
