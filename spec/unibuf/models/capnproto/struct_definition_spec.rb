# frozen_string_literal: true

require "spec_helper"
require "unibuf/models/capnproto/struct_definition"
require "unibuf/models/capnproto/field_definition"
require "unibuf/models/capnproto/union_definition"

RSpec.describe Unibuf::Models::Capnproto::StructDefinition do
  describe "initialization" do
    it "creates struct with name and fields" do
      field = Unibuf::Models::Capnproto::FieldDefinition.new(
        name: "id",
        ordinal: 0,
        type: "UInt32"
      )
      struct = described_class.new(name: "Person", fields: [field])

      expect(struct.name).to eq("Person")
      expect(struct.fields.length).to eq(1)
    end

    it "creates struct with unions" do
      union = Unibuf::Models::Capnproto::UnionDefinition.new(fields: [])
      struct = described_class.new(name: "Message", unions: [union])

      expect(struct.unions.length).to eq(1)
    end

    it "creates struct with nested types" do
      nested_struct = described_class.new(name: "Inner", fields: [])
      struct = described_class.new(
        name: "Outer",
        nested_structs: [nested_struct]
      )

      expect(struct.nested_structs.length).to eq(1)
    end
  end

  describe "queries" do
    let(:field1) do
      Unibuf::Models::Capnproto::FieldDefinition.new(
        name: "id",
        ordinal: 0,
        type: "UInt32"
      )
    end

    let(:field2) do
      Unibuf::Models::Capnproto::FieldDefinition.new(
        name: "name",
        ordinal: 1,
        type: "Text"
      )
    end

    let(:struct_def) do
      described_class.new(name: "Person", fields: [field1, field2])
    end

    it "finds field by name" do
      expect(struct_def.find_field("id")).to eq(field1)
      expect(struct_def.find_field("name")).to eq(field2)
    end

    it "returns field names" do
      expect(struct_def.field_names).to eq(["id", "name"])
    end

    it "returns ordinals" do
      expect(struct_def.ordinals).to eq([0, 1])
    end

    it "returns max ordinal" do
      expect(struct_def.max_ordinal).to eq(1)
    end

    it "returns -1 for empty struct" do
      empty_struct = described_class.new(name: "Empty", fields: [])
      expect(empty_struct.max_ordinal).to eq(-1)
    end
  end

  describe "validation" do
    it "requires name" do
      struct = described_class.new(fields: [])

      expect(struct.valid?).to be false
      expect { struct.validate! }.to raise_error(Unibuf::ValidationError, /name required/)
    end

    it "requires at least one field or union" do
      struct = described_class.new(name: "Empty", fields: [])

      expect(struct.valid?).to be false
      expect { struct.validate! }.to raise_error(Unibuf::ValidationError, /at least one field/)
    end

    it "detects duplicate ordinals" do
      field1 = Unibuf::Models::Capnproto::FieldDefinition.new(
        name: "a",
        ordinal: 0,
        type: "UInt32"
      )
      field2 = Unibuf::Models::Capnproto::FieldDefinition.new(
        name: "b",
        ordinal: 0,
        type: "UInt32"
      )
      struct = described_class.new(name: "Test", fields: [field1, field2])

      expect(struct.valid?).to be false
      expect { struct.validate! }.to raise_error(Unibuf::ValidationError, /Duplicate ordinals/)
    end

    it "validates successfully with valid fields" do
      field = Unibuf::Models::Capnproto::FieldDefinition.new(
        name: "id",
        ordinal: 0,
        type: "UInt32"
      )
      struct = described_class.new(name: "Person", fields: [field])

      expect(struct.valid?).to be true
      expect { struct.validate! }.not_to raise_error
    end
  end

  describe "to_h" do
    it "serializes to hash" do
      field = Unibuf::Models::Capnproto::FieldDefinition.new(
        name: "id",
        ordinal: 0,
        type: "UInt32"
      )
      struct = described_class.new(
        name: "Person",
        fields: [field],
        annotations: [{ name: "annotation", value: true }]
      )

      hash = struct.to_h

      expect(hash[:name]).to eq("Person")
      expect(hash[:fields]).to be_an(Array)
      expect(hash[:fields].first[:name]).to eq("id")
      expect(hash[:annotations]).to be_an(Array)
    end
  end
end