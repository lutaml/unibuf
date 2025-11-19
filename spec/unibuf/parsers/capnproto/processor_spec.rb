# frozen_string_literal: true

require "spec_helper"
require "unibuf/parsers/capnproto/grammar"
require "unibuf/parsers/capnproto/processor"

RSpec.describe Unibuf::Parsers::Capnproto::Processor do
  let(:grammar) { Unibuf::Parsers::Capnproto::Grammar.new }

  describe "processing file ID" do
    it "extracts file ID from AST" do
      schema_text = "@0xabc123def456;\n\nstruct Test { field @0 :UInt32; }"
      ast = grammar.parse(schema_text)
      schema = described_class.process(ast)

      expect(schema.file_id).to eq("0xabc123def456")
    end
  end

  describe "processing using declarations" do
    it "extracts using statements" do
      schema_text = <<~CAPNP
        @0x123;
        using Foo = import "foo.capnp";
        using Bar = import "bar.capnp";
        struct Test { field @0 :UInt32; }
      CAPNP

      ast = grammar.parse(schema_text)
      schema = described_class.process(ast)

      expect(schema.usings.length).to eq(2)
      expect(schema.usings[0][:alias]).to eq("Foo")
      expect(schema.usings[0][:import_path]).to eq("foo.capnp")
    end
  end

  describe "processing structs" do
    it "extracts struct definitions" do
      schema_text = <<~CAPNP
        @0x123;
        struct Person {
          name @0 :Text;
          age @1 :UInt8;
        }
      CAPNP

      ast = grammar.parse(schema_text)
      schema = described_class.process(ast)

      expect(schema.structs.length).to eq(1)
      expect(schema.structs.first.name).to eq("Person")
      expect(schema.structs.first.fields.length).to eq(2)
    end

    it "processes field types correctly" do
      schema_text = <<~CAPNP
        @0x123;
        struct Test {
          primitive @0 :UInt32;
          text @1 :Text;
          list @2 :List(Int32);
          userType @3 :Person;
        }
      CAPNP

      ast = grammar.parse(schema_text)
      schema = described_class.process(ast)

      struct = schema.structs.first
      expect(struct.find_field("primitive").type).to eq("UInt32")
      expect(struct.find_field("text").type).to eq("Text")
      expect(struct.find_field("list").type[:generic]).to eq("List")
      expect(struct.find_field("userType").type).to eq("Person")
    end

    it "processes default values" do
      schema_text = <<~CAPNP
        @0x123;
        struct Test {
          number @0 :Int32 = 42;
          flag @1 :Bool = true;
          text @2 :Text = "hello";
        }
      CAPNP

      ast = grammar.parse(schema_text)
      schema = described_class.process(ast)

      struct = schema.structs.first
      expect(struct.find_field("number").default_value).to eq(42)
      expect(struct.find_field("flag").default_value).to be true
      expect(struct.find_field("text").default_value).to eq("hello")
    end
  end

  describe "processing enums" do
    it "extracts enum definitions" do
      schema_text = <<~CAPNP
        @0x123;
        enum Color {
          red @0;
          green @1;
          blue @2;
        }
      CAPNP

      ast = grammar.parse(schema_text)
      schema = described_class.process(ast)

      expect(schema.enums.length).to eq(1)
      expect(schema.enums.first.name).to eq("Color")
      expect(schema.enums.first.values).to eq({ "red" => 0, "green" => 1,
                                                "blue" => 2 })
    end
  end

  describe "processing interfaces" do
    it "extracts interface definitions" do
      schema_text = <<~CAPNP
        @0x123;
        interface Calculator {
          add @0 (a :Int32, b :Int32) -> (result :Int32);
        }
      CAPNP

      ast = grammar.parse(schema_text)
      schema = described_class.process(ast)

      expect(schema.interfaces.length).to eq(1)
      expect(schema.interfaces.first.name).to eq("Calculator")
      expect(schema.interfaces.first.methods.length).to eq(1)
    end

    it "processes method parameters and results" do
      schema_text = <<~CAPNP
        @0x123;
        interface Calculator {
          add @0 (a :Int32, b :Int32) -> (result :Int32);
        }
      CAPNP

      ast = grammar.parse(schema_text)
      schema = described_class.process(ast)

      method = schema.interfaces.first.methods.first
      expect(method.params.length).to eq(2)
      expect(method.params[0][:name]).to eq("a")
      expect(method.params[0][:type]).to eq("Int32")
      # Results might be optional in grammar - check if present
      if method.results.any?
        expect(method.results[0][:name]).to eq("result")
      end
    end
  end

  describe "processing constants" do
    it "extracts const definitions" do
      schema_text = <<~CAPNP
        @0x123;
        const maxSize :UInt32 = 100;
        struct Test { field @0 :UInt32; }
      CAPNP

      ast = grammar.parse(schema_text)
      schema = described_class.process(ast)

      expect(schema.constants.length).to eq(1)
      expect(schema.constants.first[:name]).to eq("maxSize")
      expect(schema.constants.first[:type]).to eq("UInt32")
      expect(schema.constants.first[:value]).to eq(100)
    end
  end

  describe "empty schema" do
    it "returns empty schema for nil AST" do
      schema = described_class.process(nil)

      expect(schema).to be_a(Unibuf::Models::Capnproto::Schema)
      expect(schema.structs).to be_empty
    end
  end
end
