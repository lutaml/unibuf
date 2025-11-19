# frozen_string_literal: true

require "spec_helper"
require "unibuf/models/capnproto/schema"
require "unibuf/models/capnproto/struct_definition"
require "unibuf/models/capnproto/field_definition"
require "unibuf/models/capnproto/enum_definition"
require "unibuf/models/capnproto/interface_definition"

RSpec.describe Unibuf::Models::Capnproto::Schema do
  describe "initialization" do
    it "creates schema with file_id" do
      schema = described_class.new(file_id: "0x123456")
      expect(schema.file_id).to eq("0x123456")
    end

    it "creates schema with structs" do
      struct = Unibuf::Models::Capnproto::StructDefinition.new(
        name: "Person",
        fields: [],
      )
      schema = described_class.new(structs: [struct])

      expect(schema.structs.length).to eq(1)
      expect(schema.structs.first.name).to eq("Person")
    end

    it "creates schema with enums" do
      enum = Unibuf::Models::Capnproto::EnumDefinition.new(
        name: "Color",
        values: { "red" => 0, "green" => 1 },
      )
      schema = described_class.new(enums: [enum])

      expect(schema.enums.length).to eq(1)
    end

    it "creates schema with interfaces" do
      interface = Unibuf::Models::Capnproto::InterfaceDefinition.new(
        name: "Calculator",
        methods: [],
      )
      schema = described_class.new(interfaces: [interface])

      expect(schema.interfaces.length).to eq(1)
    end
  end

  describe "queries" do
    let(:struct1) do
      Unibuf::Models::Capnproto::StructDefinition.new(
        name: "Person",
        fields: [],
      )
    end

    let(:struct2) do
      Unibuf::Models::Capnproto::StructDefinition.new(
        name: "Address",
        fields: [],
      )
    end

    let(:enum1) do
      Unibuf::Models::Capnproto::EnumDefinition.new(
        name: "Color",
        values: { "red" => 0 },
      )
    end

    let(:interface1) do
      Unibuf::Models::Capnproto::InterfaceDefinition.new(
        name: "Calculator",
        methods: [],
      )
    end

    let(:schema) do
      described_class.new(
        file_id: "0x123",
        structs: [struct1, struct2],
        enums: [enum1],
        interfaces: [interface1],
      )
    end

    it "finds struct by name" do
      expect(schema.find_struct("Person")).to eq(struct1)
      expect(schema.find_struct("Address")).to eq(struct2)
    end

    it "finds enum by name" do
      expect(schema.find_enum("Color")).to eq(enum1)
    end

    it "finds interface by name" do
      expect(schema.find_interface("Calculator")).to eq(interface1)
    end

    it "finds any type by name" do
      expect(schema.find_type("Person")).to eq(struct1)
      expect(schema.find_type("Color")).to eq(enum1)
      expect(schema.find_type("Calculator")).to eq(interface1)
    end

    it "returns struct names" do
      expect(schema.struct_names).to eq(["Person", "Address"])
    end

    it "returns enum names" do
      expect(schema.enum_names).to eq(["Color"])
    end

    it "returns interface names" do
      expect(schema.interface_names).to eq(["Calculator"])
    end
  end

  describe "validation" do
    it "requires file_id" do
      schema = described_class.new(structs: [])

      expect(schema.valid?).to be false
      expect do
        schema.validate!
      end.to raise_error(Unibuf::ValidationError, /File ID required/)
    end

    it "validates successfully with file_id" do
      struct = Unibuf::Models::Capnproto::StructDefinition.new(
        name: "Test",
        fields: [
          Unibuf::Models::Capnproto::FieldDefinition.new(
            name: "value",
            ordinal: 0,
            type: "UInt32",
          ),
        ],
      )
      schema = described_class.new(
        file_id: "0x123",
        structs: [struct],
      )

      expect(schema.valid?).to be true
      expect { schema.validate! }.not_to raise_error
    end
  end

  describe "to_h" do
    it "serializes to hash" do
      schema = described_class.new(
        file_id: "0x123",
        usings: [{ alias: "Foo", import_path: "foo.capnp" }],
        structs: [],
        enums: [],
        interfaces: [],
        constants: [],
      )

      hash = schema.to_h

      expect(hash[:file_id]).to eq("0x123")
      expect(hash[:usings]).to be_an(Array)
      expect(hash[:structs]).to be_an(Array)
      expect(hash[:enums]).to be_an(Array)
      expect(hash[:interfaces]).to be_an(Array)
      expect(hash[:constants]).to be_an(Array)
    end
  end
end
