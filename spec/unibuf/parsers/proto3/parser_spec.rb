# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Proto3 Parser Integration" do
  let(:proto3_grammar) { Unibuf::Parsers::Proto3::Grammar.new }
  let(:proto3_processor) { Unibuf::Parsers::Proto3::Processor }

  describe "parsing metadata.proto" do
    let(:schema_path) { File.expand_path("../../../fixtures/metadata.proto", __dir__) }

    it "parses the schema file" do
      skip "Schema file not found" unless File.exist?(schema_path)

      content = File.read(schema_path)
      ast = proto3_grammar.parse(content)
      schema = proto3_processor.process(ast)

      expect(schema).to be_a(Unibuf::Models::Schema)
      expect(schema.package).to eq("google.fonts")
      expect(schema.messages.size).to be > 0
    end

    it "extracts message definitions" do
      skip "Schema file not found" unless File.exist?(schema_path)

      content = File.read(schema_path)
      ast = proto3_grammar.parse(content)
      schema = proto3_processor.process(ast)

      expect(schema.message_names).to include("FamilyProto")
      expect(schema.message_names).to include("FontProto")
    end

    it "extracts field definitions" do
      skip "Schema file not found" unless File.exist?(schema_path)

      content = File.read(schema_path)
      ast = proto3_grammar.parse(content)
      schema = proto3_processor.process(ast)

      family_proto = schema.find_message("FamilyProto")
      expect(family_proto).not_to be_nil
      expect(family_proto.fields.size).to be > 0
      expect(family_proto.field_names).to include("name")
    end

    it "handles repeated fields" do
      skip "Schema file not found" unless File.exist?(schema_path)

      content = File.read(schema_path)
      ast = proto3_grammar.parse(content)
      schema = proto3_processor.process(ast)

      family_proto = schema.find_message("FamilyProto")
      fonts_field = family_proto.find_field("fonts")
      expect(fonts_field).not_to be_nil
      expect(fonts_field.repeated?).to be true
    end

    it "handles map fields" do
      skip "Schema file not found" unless File.exist?(schema_path)

      content = File.read(schema_path)
      ast = proto3_grammar.parse(content)
      schema = proto3_processor.process(ast)

      family_proto = schema.find_message("FamilyProto")
      map_field = family_proto.find_field("registry_default_overrides")

      if map_field
        expect(map_field.map?).to be true
        expect(map_field.key_type).not_to be_nil
        expect(map_field.value_type).not_to be_nil
      end
    end
  end

  describe "Unibuf.parse_schema" do
    let(:schema_path) { File.expand_path("../../../fixtures/metadata.proto", __dir__) }

    it "provides high-level API" do
      skip "Schema file not found" unless File.exist?(schema_path)

      schema = Unibuf.parse_schema(schema_path)

      expect(schema).to be_a(Unibuf::Models::Schema)
      expect(schema.package).to eq("google.fonts")
      expect(schema.messages.size).to be > 0
    end

    it "is aliased as load_schema" do
      skip "Schema file not found" unless File.exist?(schema_path)

      schema = Unibuf.load_schema(schema_path)
      expect(schema).to be_a(Unibuf::Models::Schema)
    end

    it "is aliased as parse_proto3" do
      skip "Schema file not found" unless File.exist?(schema_path)

      schema = Unibuf.parse_proto3(schema_path)
      expect(schema).to be_a(Unibuf::Models::Schema)
    end
  end
end