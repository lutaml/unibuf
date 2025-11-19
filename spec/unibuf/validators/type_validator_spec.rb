# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Validators::TypeValidator do
  describe "field validation" do
    it "validates string fields" do
      field = Unibuf::Models::Field.new("name" => "test", "value" => "hello")
      expect { described_class.validate_field(field, :string) }.not_to raise_error
    end

    it "validates int32 fields" do
      field = Unibuf::Models::Field.new("name" => "count", "value" => 42)
      expect { described_class.validate_field(field, :int32) }.not_to raise_error
    end

    it "validates int32 range" do
      field = Unibuf::Models::Field.new("name" => "max", "value" => 2**31 - 1)
      expect { described_class.validate_field(field, :int32) }.not_to raise_error

      field = Unibuf::Models::Field.new("name" => "min", "value" => -2**31)
      expect { described_class.validate_field(field, :int32) }.not_to raise_error
    end

    it "rejects int32 out of range" do
      field = Unibuf::Models::Field.new("name" => "too_big", "value" => 2**31)
      expect {
        described_class.validate_field(field, :int32)
      }.to raise_error(Unibuf::TypeValidationError, /out of range/)
    end

    it "validates uint32 fields" do
      field = Unibuf::Models::Field.new("name" => "count", "value" => 42)
      expect { described_class.validate_field(field, :uint32) }.not_to raise_error
    end

    it "validates uint32 range" do
      field = Unibuf::Models::Field.new("name" => "max", "value" => 2**32 - 1)
      expect { described_class.validate_field(field, :uint32) }.not_to raise_error

      field = Unibuf::Models::Field.new("name" => "zero", "value" => 0)
      expect { described_class.validate_field(field, :uint32) }.not_to raise_error
    end

    it "rejects negative uint32" do
      field = Unibuf::Models::Field.new("name" => "negative", "value" => -1)
      expect {
        described_class.validate_field(field, :uint32)
      }.to raise_error(Unibuf::TypeValidationError, /out of range/)
    end

    it "validates float fields" do
      field = Unibuf::Models::Field.new("name" => "pi", "value" => 3.14)
      expect { described_class.validate_field(field, :float) }.not_to raise_error

      field = Unibuf::Models::Field.new("name" => "int", "value" => 42)
      expect { described_class.validate_field(field, :float) }.not_to raise_error
    end

    it "validates bool fields" do
      field = Unibuf::Models::Field.new("name" => "flag", "value" => true)
      expect { described_class.validate_field(field, :bool) }.not_to raise_error

      field = Unibuf::Models::Field.new("name" => "flag", "value" => false)
      expect { described_class.validate_field(field, :bool) }.not_to raise_error
    end

    it "rejects wrong types" do
      field = Unibuf::Models::Field.new("name" => "test", "value" => "string")
      expect {
        described_class.validate_field(field, :int32)
      }.to raise_error(Unibuf::TypeValidationError)
    end

    it "allows nil for optional fields" do
      field = Unibuf::Models::Field.new("name" => "optional", "value" => nil)
      expect { described_class.validate_field(field, :string) }.not_to raise_error
    end

    it "raises on unknown type" do
      field = Unibuf::Models::Field.new("name" => "test", "value" => "val")
      expect {
        described_class.validate_field(field, :unknown_type)
      }.to raise_error(Unibuf::TypeValidationError, /Unknown type/)
    end
  end

  describe "message validation" do
    it "validates all fields in message" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "name", "value" => "test" },
          { "name" => "count", "value" => 42 }
        ]
      )

      schema = {
        "name" => :string,
        "count" => :int32
      }

      errors = described_class.validate_message(message, schema)
      expect(errors).to be_empty
    end

    it "reports type errors" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "count", "value" => "not a number" }
        ]
      )

      schema = { "count" => :int32 }

      errors = described_class.validate_message(message, schema)
      expect(errors.size).to be > 0
    end

    it "skips fields not in schema" do
      message = Unibuf::Models::Message.new(
        "fields" => [
          { "name" => "unknown", "value" => "test" }
        ]
      )

      errors = described_class.validate_message(message, {})
      expect(errors).to be_empty
    end
  end

  describe "type checking helpers" do
    it "identifies numeric types" do
      expect(described_class.numeric_type?(:int32)).to be true
      expect(described_class.numeric_type?(:float)).to be true
      expect(described_class.numeric_type?(:string)).to be false
    end

    it "identifies signed types" do
      expect(described_class.signed_type?(:int32)).to be true
      expect(described_class.signed_type?(:sint32)).to be true
      expect(described_class.signed_type?(:uint32)).to be false
    end

    it "identifies unsigned types" do
      expect(described_class.unsigned_type?(:uint32)).to be true
      expect(described_class.unsigned_type?(:int32)).to be false
    end
  end
end