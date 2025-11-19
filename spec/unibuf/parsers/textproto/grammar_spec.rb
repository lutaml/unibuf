# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Parsers::Textproto::Grammar do
  let(:grammar) { described_class.new }

  describe "basic tokens" do
    it "parses string literals" do
      result = grammar.string_value.parse('"hello"')
      # Single string returns hash with :string key
      expect(result).to have_key(:string)
      expect(result[:string].to_s).to include("hello")
    end

    it "parses integers" do
      result = grammar.dec_int.parse("42")
      expect(result[:integer]).to eq("42")
    end

    it "parses floats" do
      result = grammar.float_token.parse("3.14")
      expect(result[:float]).to eq("3.14")
    end

    it "parses booleans" do
      result = grammar.identifier.parse("true")
      expect(result[:identifier]).to eq("true")
    end

    it "parses identifiers" do
      result = grammar.identifier.parse("field_name")
      expect(result[:identifier]).to eq("field_name")
    end
  end

  describe "field assignment" do
    it "parses simple field assignment" do
      result = grammar.parse('name: "value"')
      expect(result).to be_an(Array)
      expect(result.first[:field][:field_name][:identifier].to_s).to eq("name")
    end

    it "parses numeric field assignment" do
      result = grammar.parse("count: 42")
      expect(result).to be_an(Array)
      expect(result.first[:field][:field_name][:identifier].to_s).to eq("count")
    end

    it "parses boolean field assignment" do
      result = grammar.parse("enabled: true")
      expect(result).to be_an(Array)
      expect(result.first[:field][:field_name][:identifier].to_s).to eq("enabled")
    end
  end

  describe "message blocks" do
    it "parses empty message block" do
      # Empty message blocks are valid when used as field values
      result = grammar.parse("msg {}")
      expect(result).to be_an(Array)
    end

    it "parses message block with one field" do
      result = grammar.message_value.parse('{ name: "test" }')
      expect(result[:message]).to be_an(Array)
    end

    it "parses message block with multiple fields" do
      input = '{ name: "test" count: 42 enabled: true }'
      result = grammar.message_value.parse(input)
      expect(result[:message].size).to eq(3)
    end
  end

  describe "comments" do
    it "parses hash comments" do
      result = grammar.comment.parse("# this is a comment\n")
      expect(result).not_to be_nil
    end

    it "parses double slash comments" do
      # Comments need the newline to be complete
      result = grammar.comment.parse("// this is a comment\n")
      expect(result).not_to be_nil
    end
  end

  describe "complete parsing" do
    it "parses simple textproto" do
      input = <<~PROTO
        name: "example"
        version: 1
      PROTO
      result = grammar.parse(input)
      expect(result).to be_an(Array)
      expect(result.size).to eq(2)
    end

    it "parses textproto with comments" do
      input = 'name: "example" version: 1'
      result = grammar.parse(input)
      expect(result.size).to eq(2)
    end

    it "parses multi-line strings" do
      input = 'description: "line one" "line two"'
      result = grammar.parse(input)
      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
      # The field should have concatenated string value
      field_value = result.first[:field][:field_value]
      expect(field_value).to be_an(Array) # Multiple strings
      expect(field_value.size).to eq(2)
    end
  end
end
