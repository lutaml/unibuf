# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Validators::SchemaValidator do
  let(:field_def1) do
    Unibuf::Models::FieldDefinition.new(
      name: "name",
      type: "string",
      number: 1,
    )
  end

  let(:field_def2) do
    Unibuf::Models::FieldDefinition.new(
      name: "count",
      type: "int32",
      number: 2,
    )
  end

  let(:msg_def) do
    Unibuf::Models::MessageDefinition.new(
      name: "TestMessage",
      fields: [field_def1, field_def2],
    )
  end

  let(:schema) do
    Unibuf::Models::Schema.new(
      package: "test",
      messages: [msg_def],
    )
  end

  let(:validator) { described_class.new(schema) }

  describe "initialization" do
    it "creates with schema" do
      expect(validator.schema).to eq(schema)
    end
  end

  describe "validation" do
    it "validates message with correct fields" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "hello" },
          { "name" => "count", "value" => 42 },
        ],
      )

      errors = validator.validate(message, "TestMessage")
      expect(errors).to be_empty
    end

    it "reports unknown fields" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "unknown", "value" => "test" },
        ],
      )

      errors = validator.validate(message, "TestMessage")
      expect(errors.size).to be > 0
      expect(errors.first).to include("Unknown field")
    end

    it "reports type mismatches" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "count", "value" => "string" }, # Should be int32
        ],
      )

      errors = validator.validate(message, "TestMessage")
      expect(errors.size).to be > 0
      expect(errors.first).to include("Invalid value")
    end

    it "validates nested messages" do
      nested_field_def = Unibuf::Models::FieldDefinition.new(
        name: "nested_name",
        type: "string",
        number: 1,
      )

      nested_msg_def = Unibuf::Models::MessageDefinition.new(
        name: "NestedMessage",
        fields: [nested_field_def],
      )

      parent_field_def = Unibuf::Models::FieldDefinition.new(
        name: "nested",
        type: "NestedMessage",
        number: 1,
      )

      parent_msg_def = Unibuf::Models::MessageDefinition.new(
        name: "ParentMessage",
        fields: [parent_field_def],
      )

      schema_with_nested = Unibuf::Models::Schema.new(
        messages: [parent_msg_def, nested_msg_def],
      )

      nested_validator = described_class.new(schema_with_nested)

      message = Unibuf::Models::Message.new(
        "fields" => [
          {
            "name" => "nested",
            "value" => {
              "fields" => [
                { "name" => "nested_name", "value" => "hello" },
              ],
            },
          },
        ],
      )

      errors = nested_validator.validate(message, "ParentMessage")
      expect(errors).to be_empty
    end

    it "detects errors in nested messages" do
      nested_field_def = Unibuf::Models::FieldDefinition.new(
        name: "nested_name",
        type: "string",
        number: 1,
      )

      nested_msg_def = Unibuf::Models::MessageDefinition.new(
        name: "NestedMessage",
        fields: [nested_field_def],
      )

      parent_field_def = Unibuf::Models::FieldDefinition.new(
        name: "nested",
        type: "NestedMessage",
        number: 1,
      )

      parent_msg_def = Unibuf::Models::MessageDefinition.new(
        name: "ParentMessage",
        fields: [parent_field_def],
      )

      schema_with_nested = Unibuf::Models::Schema.new(
        messages: [parent_msg_def, nested_msg_def],
      )

      nested_validator = described_class.new(schema_with_nested)

      message = Unibuf::Models::Message.new(
        "fields" => [
          {
            "name" => "nested",
            "value" => {
              "fields" => [
                { "name" => "wrong_name", "value" => "bad" }, # Wrong field
              ],
            },
          },
        ],
      )

      errors = nested_validator.validate(message, "ParentMessage")
      expect(errors.size).to be > 0
    end

    it "uses first message when type not specified and only one message" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "test" },
        ],
      )

      errors = validator.validate(message) # No type specified
      expect(errors).to be_empty
    end

    it "reports unknown message type" do
      message = Unibuf::Models::Message.new("fields" => [])

      errors = validator.validate(message, "UnknownType")
      expect(errors.size).to eq(1)
      expect(errors.first).to include("Unknown message type")
    end
  end

  describe "validate!" do
    it "raises on validation errors" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "unknown", "value" => "test" },
        ],
      )

      expect do
        validator.validate!(message, "TestMessage")
      end.to raise_error(Unibuf::SchemaValidationError)
    end

    it "returns true when valid" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "hello" },
        ],
      )

      expect(validator.validate!(message, "TestMessage")).to be true
    end
  end
end
