# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Cap'n Proto Integration" do
  let(:fixture_path) do
    File.join(__dir__, "../../../fixtures/addressbook.capnp")
  end

  describe "parsing addressbook.capnp" do
    it "parses the schema file successfully" do
      schema = Unibuf.parse_capnproto_schema(fixture_path)

      expect(schema).to be_a(Unibuf::Models::Capnproto::Schema)
      expect(schema.file_id).to eq("0x9eb32e19f86ee174")
    end

    it "extracts struct definitions" do
      schema = Unibuf.parse_capnproto_schema(fixture_path)

      expect(schema.structs.size).to eq(2)
      expect(schema.struct_names).to include("Person", "AddressBook")
    end

    it "parses Person struct correctly" do
      schema = Unibuf.parse_capnproto_schema(fixture_path)
      person = schema.find_struct("Person")

      expect(person).not_to be_nil
      expect(person.name).to eq("Person")
      expect(person.fields.size).to eq(4)
      expect(person.field_names).to include("id", "name", "email", "phones")
    end

    it "parses Person fields with correct types and ordinals" do
      schema = Unibuf.parse_capnproto_schema(fixture_path)
      person = schema.find_struct("Person")

      id_field = person.find_field("id")
      expect(id_field.ordinal).to eq(0)
      expect(id_field.type).to eq("UInt32")

      name_field = person.find_field("name")
      expect(name_field.ordinal).to eq(1)
      expect(name_field.type).to eq("Text")

      phones_field = person.find_field("phones")
      expect(phones_field.ordinal).to eq(3)
      expect(phones_field.list_type?).to be true
    end

    it "parses nested PhoneNumber struct" do
      schema = Unibuf.parse_capnproto_schema(fixture_path)
      person = schema.find_struct("Person")

      expect(person.nested_structs.size).to eq(1)
      phone_number = person.nested_structs.first
      expect(phone_number.name).to eq("PhoneNumber")
      expect(phone_number.fields.size).to eq(2)
    end

    it "parses nested Type enum" do
      schema = Unibuf.parse_capnproto_schema(fixture_path)
      person = schema.find_struct("Person")
      phone_number = person.nested_structs.first

      expect(phone_number.nested_enums.size).to eq(1)
      type_enum = phone_number.nested_enums.first
      expect(type_enum.name).to eq("Type")
      expect(type_enum.values.keys).to include("mobile", "home", "work")
    end

    it "parses AddressBook struct" do
      schema = Unibuf.parse_capnproto_schema(fixture_path)
      address_book = schema.find_struct("AddressBook")

      expect(address_book).not_to be_nil
      expect(address_book.fields.size).to eq(1)

      people_field = address_book.find_field("people")
      expect(people_field.ordinal).to eq(0)
      expect(people_field.list_type?).to be true
    end

    it "validates the schema successfully" do
      schema = Unibuf.parse_capnproto_schema(fixture_path)

      expect(schema.valid?).to be true
    end
  end

  describe "CLI schema command" do
    it "can parse and display Cap'n Proto schema" do
      require "unibuf/commands/schema"

      command = Unibuf::Commands::Schema.new(format: "json")

      # Just verify it doesn't raise an error
      expect { command.run(fixture_path) }.not_to raise_error
    end
  end
end
