# frozen_string_literal: true

require "spec_helper"

RSpec.describe Unibuf::Parsers::Textproto::Processor do
  describe ".process" do
    it "handles nil AST" do
      result = described_class.process(nil)
      expect(result).to eq({ "fields" => [] })
    end

    it "handles empty AST" do
      result = described_class.process([])
      expect(result).to eq({ "fields" => [] })
    end

    it "processes simple scalar field" do
      ast = [
        {
          field: {
            field_name: { identifier: "name" },
            field_value: { string: '"hello"' },
          },
        },
      ]
      result = described_class.process(ast)
      expect(result["fields"].size).to eq(1)
      expect(result["fields"].first["name"]).to eq("name")
      expect(result["fields"].first["value"]).to eq("hello")
    end

    it "processes integer field" do
      ast = [
        {
          field: {
            field_name: { identifier: "count" },
            field_value: { integer: "42" },
          },
        },
      ]
      result = described_class.process(ast)
      expect(result["fields"].first["value"]).to eq(42)
    end

    it "processes float field" do
      ast = [
        {
          field: {
            field_name: { identifier: "pi" },
            field_value: { float: "3.14" },
          },
        },
      ]
      result = described_class.process(ast)
      expect(result["fields"].first["value"]).to eq(3.14)
    end

    it "processes boolean true" do
      ast = [
        {
          field: {
            field_name: { identifier: "enabled" },
            field_value: { identifier: "true" },
          },
        },
      ]
      result = described_class.process(ast)
      expect(result["fields"].first["value"]).to be true
    end

    it "processes boolean false" do
      ast = [
        {
          field: {
            field_name: { identifier: "enabled" },
            field_value: { identifier: "false" },
          },
        },
      ]
      result = described_class.process(ast)
      expect(result["fields"].first["value"]).to be false
    end

    it "processes enum identifier" do
      ast = [
        {
          field: {
            field_name: { identifier: "category" },
            field_value: { identifier: "SANS_SERIF" },
          },
        },
      ]
      result = described_class.process(ast)
      expect(result["fields"].first["value"]).to eq("SANS_SERIF")
    end

    it "processes nested message" do
      ast = [
        {
          field: {
            field_name: { identifier: "fonts" },
            field_value: {
              message: [
                {
                  field: {
                    field_name: { identifier: "name" },
                    field_value: { string: '"Roboto"' },
                  },
                },
              ],
            },
          },
        },
      ]
      result = described_class.process(ast)
      nested = result["fields"].first["value"]
      expect(nested).to be_a(Hash)
      expect(nested["fields"]).to be_an(Array)
      expect(nested["fields"].first["name"]).to eq("name")
    end

    it "processes multi-line concatenated strings" do
      ast = [
        {
          field: {
            field_name: { identifier: "description" },
            field_value: [
              { string: '"line one"' },
              { string: '"line two"' },
            ],
          },
        },
      ]
      result = described_class.process(ast)
      expect(result["fields"].first["value"]).to eq("line oneline two")
    end

    it "processes lists" do
      ast = [
        {
          field: {
            field_name: { identifier: "tags" },
            field_value: {
              list: [
                { string: '"tag1"' },
                { string: '"tag2"' },
              ],
            },
          },
        },
      ]
      result = described_class.process(ast)
      expect(result["fields"].first["value"]).to eq(["tag1", "tag2"])
    end

    it "handles escape sequences in strings" do
      ast = [
        {
          field: {
            field_name: { identifier: "text" },
            field_value: { string: '"line1\\\\nline2"' },
          },
        },
      ]
      result = described_class.process(ast)
      # The processor unescapes \n to actual newline
      expect(result["fields"].first["value"]).to include("\n")
    end

    it "handles multiple escape types" do
      # Test tab and carriage return
      ast_tab = [
        {
          field: {
            field_name: { identifier: "text" },
            field_value: { string: '"tab\\\\there"' },
          },
        },
      ]
      result = described_class.process(ast_tab)
      expect(result["fields"].first["value"]).to include("\t")
    end

    context "with negative numbers" do
      it "processes negative integer in scalar field" do
        ast = [
          {
            field: {
              field_name: { identifier: "offset" },
              field_value: { negative: { integer: "42" } },
            },
          },
        ]
        result = described_class.process(ast)
        expect(result["fields"].first["value"]).to eq(-42)
      end

      it "processes negative float in scalar field" do
        ast = [
          {
            field: {
              field_name: { identifier: "temperature" },
              field_value: { negative: { float: "3.14" } },
            },
          },
        ]
        result = described_class.process(ast)
        expect(result["fields"].first["value"]).to eq(-3.14)
      end

      # rubocop:disable RSpec/ExampleLength
      it "processes negative numbers in map field values" do
        ast = [
          {
            field: {
              field_name: { identifier: "registry_default_overrides" },
              field_value: {
                message: [
                  {
                    field: {
                      field_name: { identifier: "key" },
                      field_value: { string: '"YTDE"' },
                    },
                  },
                  {
                    field: {
                      field_name: { identifier: "value" },
                      field_value: { negative: { float: "203.0" } },
                    },
                  },
                ],
              },
            },
          },
        ]
        result = described_class.process(ast)
        nested = result["fields"].first["value"]
        value_field = nested["fields"].find { |f| f["name"] == "value" }
        expect(value_field["value"]).to eq(-203.0)
      end
      # rubocop:enable RSpec/ExampleLength

      it "processes negative numbers in lists" do
        ast = [
          {
            field: {
              field_name: { identifier: "coordinates" },
              field_value: {
                list: [
                  { negative: { float: "1.5" } },
                  { negative: { integer: "42" } },
                  { float: "3.14" },
                ],
              },
            },
          },
        ]
        result = described_class.process(ast)
        expect(result["fields"].first["value"]).to eq([-1.5, -42, 3.14])
      end
    end
  end
end
