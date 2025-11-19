# frozen_string_literal: true

require "spec_helper"
require "unibuf/parsers/capnproto/grammar"

RSpec.describe Unibuf::Parsers::Capnproto::Grammar do
  let(:grammar) { described_class.new }

  describe "basic tokens" do
    it "parses identifiers" do
      result = grammar.identifier.parse("Person")
      expect(result[:identifier]).to eq("Person")
    end

    it "parses strings" do
      result = grammar.string_literal.parse('"hello"')
      expect(result[:string]).to eq("hello")
    end

    it "parses integers" do
      result = grammar.number.parse("42")
      expect(result[:number]).to eq("42")
    end

    it "parses negative integers" do
      result = grammar.number.parse("-10")
      expect(result[:number]).to eq("-10")
    end

    it "parses floats" do
      result = grammar.number.parse("3.14")
      expect(result[:number]).to eq("3.14")
    end

    it "parses hex numbers" do
      result = grammar.number.parse("0xabc123")
      expect(result[:number]).to eq("0xabc123")
    end

    it "parses booleans" do
      result = grammar.bool_literal.parse("true")
      expect(result[:bool]).to eq("true")
    end
  end

  describe "file ID" do
    it "parses file ID" do
      result = grammar.file_id.parse("@0xabc123def456;")
      expect(result[:number]).to eq("0xabc123def456")
    end

    it "parses uppercase hex file ID" do
      result = grammar.file_id.parse("@0xABCDEF123456;")
      expect(result[:number]).to eq("0xABCDEF123456")
    end
  end

  describe "using statement" do
    it "parses simple using declaration" do
      result = grammar.using_stmt.parse('using Foo = import "foo.capnp";')
      expect(result[:alias][:identifier]).to eq("Foo")
      expect(result[:import_path][:string]).to eq("foo.capnp")
    end

    it "parses using declaration with path" do
      result = grammar.using_stmt.parse('using Bar = import "path/to/bar.capnp";')
      expect(result[:alias][:identifier]).to eq("Bar")
      expect(result[:import_path][:string]).to eq("path/to/bar.capnp")
    end
  end

  describe "primitive types" do
    it "parses Void type" do
      result = grammar.primitive_type.parse("Void")
      expect(result[:primitive_type]).to eq("Void")
    end

    it "parses Bool type" do
      result = grammar.primitive_type.parse("Bool")
      expect(result[:primitive_type]).to eq("Bool")
    end

    it "parses Int32 type" do
      result = grammar.primitive_type.parse("Int32")
      expect(result[:primitive_type]).to eq("Int32")
    end

    it "parses UInt64 type" do
      result = grammar.primitive_type.parse("UInt64")
      expect(result[:primitive_type]).to eq("UInt64")
    end

    it "parses Text type" do
      result = grammar.primitive_type.parse("Text")
      expect(result[:primitive_type]).to eq("Text")
    end

    it "parses Data type" do
      result = grammar.primitive_type.parse("Data")
      expect(result[:primitive_type]).to eq("Data")
    end
  end

  describe "generic types" do
    it "parses List of primitive" do
      result = grammar.generic_type.parse("List(Int32)")
      expect(result).to be_a(Hash)
    end

    it "parses List of user type" do
      result = grammar.generic_type.parse("List(Person)")
      expect(result).to be_a(Hash)
    end

    it "parses nested List" do
      result = grammar.generic_type.parse("List(List(Text))")
      expect(result).to be_a(Hash)
    end
  end

  describe "field definition" do
    it "parses simple field" do
      result = grammar.field_def.parse("name @0 :Text;")
      expect(result[:name][:identifier]).to eq("name")
      expect(result[:ordinal][:number]).to eq("0")
    end

    it "parses field with integer type" do
      result = grammar.field_def.parse("age @1 :UInt8;")
      expect(result[:name][:identifier]).to eq("age")
      expect(result[:ordinal][:number]).to eq("1")
    end

    it "parses field with list type" do
      result = grammar.field_def.parse("phones @2 :List(Text);")
      expect(result[:name][:identifier]).to eq("phones")
      expect(result[:ordinal][:number]).to eq("2")
    end

    it "parses field with default value" do
      result = grammar.field_def.parse("active @3 :Bool = true;")
      expect(result[:name][:identifier]).to eq("active")
      expect(result[:default]).to be_a(Hash)
    end
  end

  describe "struct definition" do
    it "parses simple struct" do
      schema = <<~CAPNP.strip
        struct Person {
          name @0 :Text;
        }
      CAPNP

      result = grammar.struct_def.parse(schema)
      expect(result[:struct_name][:identifier]).to eq("Person")
    end

    it "parses struct with multiple fields" do
      schema = <<~CAPNP.strip
        struct Person {
          name @0 :Text;
          age @1 :UInt8;
          email @2 :Text;
        }
      CAPNP

      result = grammar.struct_def.parse(schema)
      expect(result[:struct_name][:identifier]).to eq("Person")
    end

    it "parses struct with list field" do
      schema = <<~CAPNP.strip
        struct Person {
          phones @0 :List(Text);
        }
      CAPNP

      result = grammar.struct_def.parse(schema)
      expect(result[:struct_name][:identifier]).to eq("Person")
    end

    it "parses struct with user type field" do
      schema = <<~CAPNP.strip
        struct Person {
          address @0 :Address;
        }
      CAPNP

      result = grammar.struct_def.parse(schema)
      expect(result[:struct_name][:identifier]).to eq("Person")
    end
  end

  describe "enum definition" do
    it "parses simple enum" do
      schema = <<~CAPNP.strip
        enum Gender {
          male @0;
          female @1;
        }
      CAPNP

      result = grammar.enum_def.parse(schema)
      expect(result[:enum_name][:identifier]).to eq("Gender")
    end

    it "parses enum with non-sequential ordinals" do
      schema = <<~CAPNP.strip
        enum Status {
          active @0;
          inactive @5;
          pending @10;
        }
      CAPNP

      result = grammar.enum_def.parse(schema)
      expect(result[:enum_name][:identifier]).to eq("Status")
    end
  end

  describe "interface definition" do
    it "parses simple interface" do
      schema = <<~CAPNP.strip
        interface Calculator {
          add @0 (a :Int32, b :Int32) -> (result :Int32);
        }
      CAPNP

      result = grammar.interface_def.parse(schema)
      expect(result[:interface_name][:identifier]).to eq("Calculator")
    end

    it "parses interface with no return value" do
      schema = <<~CAPNP.strip
        interface Logger {
          log @0 (message :Text);
        }
      CAPNP

      result = grammar.interface_def.parse(schema)
      expect(result[:interface_name][:identifier]).to eq("Logger")
    end

    it "parses interface with multiple methods" do
      schema = <<~CAPNP.strip
        interface Calculator {
          add @0 (a :Int32, b :Int32) -> (result :Int32);
          subtract @1 (a :Int32, b :Int32) -> (result :Int32);
        }
      CAPNP

      result = grammar.interface_def.parse(schema)
      expect(result[:interface_name][:identifier]).to eq("Calculator")
    end
  end

  describe "union definition" do
    it "parses union within struct" do
      schema = <<~CAPNP.strip
        struct Message {
          union {
            text @0 :Text;
            number @1 :Int32;
          }
        }
      CAPNP

      result = grammar.struct_def.parse(schema)
      expect(result[:struct_name][:identifier]).to eq("Message")
    end
  end

  describe "const definition" do
    it "parses integer constant" do
      result = grammar.const_def.parse("const maxSize :UInt32 = 100;")
      expect(result[:name][:identifier]).to eq("maxSize")
    end

    it "parses string constant" do
      result = grammar.const_def.parse('const greeting :Text = "Hello";')
      expect(result[:name][:identifier]).to eq("greeting")
    end
  end

  describe "complete schema" do
    it "parses minimal schema" do
      schema = <<~CAPNP
        @0xabc123def456;

        struct Person {
          name @0 :Text;
        }
      CAPNP

      result = grammar.parse(schema)
      expect(result).to be_an(Array)
    end

    it "parses schema with using declaration" do
      schema = <<~CAPNP
        @0xabc123def456;

        using Foo = import "foo.capnp";

        struct Person {
          name @0 :Text;
        }
      CAPNP

      result = grammar.parse(schema)
      expect(result).to be_an(Array)
    end

    it "parses comprehensive schema" do
      schema = <<~CAPNP
        @0xabc123def456;

        using Foo = import "foo.capnp";

        struct Person {
          name @0 :Text;
          age @1 :UInt8;
          email @2 :Text;
          phones @3 :List(Text);
        }

        enum Gender {
          male @0;
          female @1;
          other @2;
        }

        interface Calculator {
          add @0 (a :Int32, b :Int32) -> (result :Int32);
        }
      CAPNP

      result = grammar.parse(schema)
      expect(result).to be_an(Array)
    end
  end

  describe "comments" do
    it "parses hash comments" do
      schema = <<~CAPNP
        # This is a comment
        @0xabc123def456;
      CAPNP

      result = grammar.parse(schema)
      expect(result).to be_an(Array)
    end

    it "parses inline comments" do
      schema = <<~CAPNP
        @0xabc123def456; # File ID

        struct Person { # Main struct
          name @0 :Text; # Name field
        }
      CAPNP

      result = grammar.parse(schema)
      expect(result).to be_an(Array)
    end
  end

  describe "annotations" do
    it "parses simple annotation" do
      result = grammar.annotation.parse("$annotation")
      expect(result[:annotation][:identifier]).to eq("annotation")
    end

    it "parses annotation with value" do
      result = grammar.annotation.parse("$annotation(123)")
      expect(result[:annotation][:identifier]).to eq("annotation")
    end
  end
end
