# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Models::Schema do
  describe "initialization" do
    it "creates with default syntax" do
      schema = described_class.new
      expect(schema.syntax).to eq("proto3")
    end

    it "creates with custom attributes" do
      msg_def = Unibuf::Models::MessageDefinition.new(name: "Test", fields: [])
      enum_def = Unibuf::Models::EnumDefinition.new(name: "Status", values: { "OK" => 0 })

      schema = described_class.new(
        syntax: "proto3",
        package: "com.example",
        imports: ["other.proto"],
        messages: [msg_def],
        enums: [enum_def]
      )

      expect(schema.syntax).to eq("proto3")
      expect(schema.package).to eq("com.example")
      expect(schema.imports.size).to eq(1)
      expect(schema.messages.size).to eq(1)
      expect(schema.enums.size).to eq(1)
    end
  end

  describe "queries" do
    let(:msg_def1) do
      Unibuf::Models::MessageDefinition.new(name: "Message1", fields: [])
    end

    let(:msg_def2) do
      Unibuf::Models::MessageDefinition.new(name: "Message2", fields: [])
    end

    let(:enum_def) do
      Unibuf::Models::EnumDefinition.new(name: "Status", values: { "OK" => 0 })
    end

    let(:schema) do
      described_class.new(
        package: "test.package",
        messages: [msg_def1, msg_def2],
        enums: [enum_def]
      )
    end

    it "finds message by name" do
      msg = schema.find_message("Message1")
      expect(msg).not_to be_nil
      expect(msg.name).to eq("Message1")
    end

    it "finds enum by name" do
      enum = schema.find_enum("Status")
      expect(enum).not_to be_nil
      expect(enum.name).to eq("Status")
    end

    it "returns nil for unknown message" do
      expect(schema.find_message("Unknown")).to be_nil
    end

    it "returns nil for unknown enum" do
      expect(schema.find_enum("Unknown")).to be_nil
    end

    it "returns message names" do
      names = schema.message_names
      expect(names).to contain_exactly("Message1", "Message2")
    end

    it "returns enum names" do
      names = schema.enum_names
      expect(names).to contain_exactly("Status")
    end

    it "finds types (message or enum)" do
      expect(schema.find_type("Message1")).to eq(msg_def1)
      expect(schema.find_type("Status")).to eq(enum_def)
      expect(schema.find_type("Unknown")).to be_nil
    end
  end

  describe "validation" do
    it "validates proto3 syntax" do
      schema = described_class.new(syntax: "proto3")
      expect(schema.valid?).to be true
      expect { schema.validate! }.not_to raise_error
    end

    it "fails validation with non-proto3 syntax" do
      schema = described_class.new(syntax: "proto2")
      expect(schema.valid?).to be false
      expect { schema.validate! }.to raise_error(Unibuf::ValidationError, /proto3/)
    end

    it "validates all messages" do
      invalid_msg = Unibuf::Models::MessageDefinition.new(fields: []) # No name
      schema = described_class.new(
        messages: [invalid_msg]
      )

      expect { schema.validate! }.to raise_error(Unibuf::ValidationError)
    end

    it "validates all enums" do
      invalid_enum = Unibuf::Models::EnumDefinition.new(name: "Bad", values: {}) # Empty
      schema = described_class.new(
        enums: [invalid_enum]
      )

      expect { schema.validate! }.to raise_error(Unibuf::ValidationError)
    end
  end

  describe "transformation" do
    it "converts to hash" do
      msg_def = Unibuf::Models::MessageDefinition.new(name: "Test", fields: [])
      schema = described_class.new(
        syntax: "proto3",
        package: "test",
        messages: [msg_def]
      )

      hash = schema.to_h
      expect(hash[:syntax]).to eq("proto3")
      expect(hash[:package]).to eq("test")
      expect(hash[:messages]).to be_an(Array)
    end
  end
end