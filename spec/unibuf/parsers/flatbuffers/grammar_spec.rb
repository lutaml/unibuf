# frozen_string_literal: true

require "spec_helper"
require "unibuf/parsers/flatbuffers/grammar"

RSpec.describe Unibuf::Parsers::Flatbuffers::Grammar do
  let(:grammar) { described_class.new }

  describe "basic tokens" do
    it "parses identifiers" do
      result = grammar.identifier.parse("Monster")
      expect(result[:identifier]).to eq("Monster")
    end

    it "parses strings" do
      result = grammar.string_literal.parse('"hello"')
      expect(result[:string]).to eq("hello")
    end

    it "parses integers" do
      result = grammar.number.parse("42")
      expect(result[:number]).to eq("42")
    end

    it "parses floats" do
      result = grammar.number.parse("3.14")
      expect(result[:number]).to eq("3.14")
    end

    it "parses booleans" do
      result = grammar.bool_literal.parse("true")
      expect(result[:bool]).to eq("true")
    end
  end

  describe "namespace" do
    it "parses simple namespace" do
      result = grammar.namespace_stmt.parse("namespace MyGame;")
      expect(result).to be_a(Hash)
    end

    it "parses dotted namespace" do
      result = grammar.namespace_stmt.parse("namespace com.example.game;")
      expect(result).to be_a(Array)
    end
  end

  describe "scalar types" do
    it "parses byte type" do
      result = grammar.scalar_type.parse("byte")
      expect(result[:scalar_type]).to eq("byte")
    end

    it "parses int type" do
      result = grammar.scalar_type.parse("int")
      expect(result[:scalar_type]).to eq("int")
    end

    it "parses string type" do
      result = grammar.scalar_type.parse("string")
      expect(result[:scalar_type]).to eq("string")
    end
  end

  describe "table definition" do
    it "parses simple table" do
      schema = <<~FBS.strip
        table Monster {
          name: string;
        }
      FBS

      result = grammar.table_def.parse(schema)
      expect(result[:table_name][:identifier]).to eq("Monster")
    end

    it "parses table with multiple fields" do
      schema = <<~FBS.strip
        table Monster {
          name: string;
          hp: int;
          mana: int = 100;
        }
      FBS

      result = grammar.table_def.parse(schema)
      expect(result[:table_name][:identifier]).to eq("Monster")
    end

    it "parses table with vector field" do
      schema = <<~FBS.strip
        table Monster {
          inventory: [ubyte];
        }
      FBS

      result = grammar.table_def.parse(schema)
      expect(result[:table_name][:identifier]).to eq("Monster")
    end
  end

  describe "struct definition" do
    it "parses simple struct" do
      schema = <<~FBS.strip
        struct Vec3 {
          x: float;
          y: float;
          z: float;
        }
      FBS

      result = grammar.struct_def.parse(schema)
      expect(result[:struct_name][:identifier]).to eq("Vec3")
    end
  end

  describe "enum definition" do
    it "parses enum with explicit values" do
      schema = <<~FBS.strip
        enum Color : byte {
          Red = 0,
          Green = 1,
          Blue = 2
        }
      FBS

      result = grammar.enum_def.parse(schema)
      expect(result[:enum_name][:identifier]).to eq("Color")
    end

    it "parses enum with implicit values" do
      schema = <<~FBS.strip
        enum Color {
          Red,
          Green,
          Blue
        }
      FBS

      result = grammar.enum_def.parse(schema)
      expect(result[:enum_name][:identifier]).to eq("Color")
    end
  end

  describe "union definition" do
    it "parses union" do
      schema = <<~FBS.strip
        union Equipment {
          Weapon,
          Armor
        }
      FBS

      result = grammar.union_def.parse(schema)
      expect(result[:union_name][:identifier]).to eq("Equipment")
    end
  end

  describe "root_type" do
    it "parses root_type declaration" do
      result = grammar.root_type_stmt.parse("root_type Monster;")
      expect(result[:root_type][:identifier]).to eq("Monster")
    end
  end

  describe "complete schema" do
    it "parses minimal schema" do
      schema = <<~FBS
        namespace MyGame;

        table Monster {
          name: string;
        }

        root_type Monster;
      FBS

      result = grammar.parse(schema)
      expect(result).to be_an(Array)
    end

    it "parses comprehensive schema" do
      schema = <<~FBS
        namespace MyGame.Sample;

        enum Color : byte { Red = 0, Green, Blue = 2 }

        table Monster {
          name: string;
          hp: int = 100;
          friendly: bool = false;
          inventory: [ubyte];
          color: Color;
        }

        root_type Monster;
      FBS

      result = grammar.parse(schema)
      expect(result).to be_an(Array)
    end
  end

  describe "comments" do
    it "parses line comments" do
      schema = <<~FBS
        // This is a comment
        namespace MyGame;
      FBS

      result = grammar.parse(schema)
      expect(result).to be_an(Array)
    end

    it "parses block comments" do
      schema = <<~FBS
        /* This is a
           block comment */
        namespace MyGame;
      FBS

      result = grammar.parse(schema)
      expect(result).to be_an(Array)
    end
  end
end
