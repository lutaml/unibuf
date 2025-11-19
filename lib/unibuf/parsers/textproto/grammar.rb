# frozen_string_literal: true

require "parslet"

module Unibuf
  module Parsers
    module Textproto
      # Parslet grammar for Protocol Buffers text format following the official spec
      # Reference: https://protobuf.dev/reference/protobuf/textformat-spec/
      class Grammar < Parslet::Parser
        # ===== Lexical Elements =====

        # Characters
        rule(:newline) { str("\n") }
        rule(:letter) { match["a-zA-Z_"] }
        rule(:dec) { match["0-9"] }
        rule(:oct) { match["0-7"] }
        rule(:hex) { match["0-9a-fA-F"] }

        # Whitespace and comments (# or //)
        rule(:comment) do
          (str("#") | str("//")) >> (newline.absent? >> any).repeat >> newline.maybe
        end
        rule(:whitespace) { match['\s'].repeat(1) | comment }
        rule(:whitespace?) { whitespace.repeat }

        # Identifiers
        rule(:ident) { letter >> (letter | dec).repeat }
        rule(:identifier) { ident.as(:identifier) }

        # String literals
        rule(:escape) do
          str("\\") >> (
            str("a") | str("b") | str("f") | str("n") | str("r") |
            str("t") | str("v") | str("?") | str("\\") | str("'") |
            str('"') |
            (oct >> oct.maybe >> oct.maybe) |
            (str("x") >> hex >> hex.maybe)
          )
        end
        rule(:string_content) { (escape | (str('"').absent? >> any)).repeat }
        rule(:single_string) do
          str("'") >> (escape | (str("'").absent? >> any)).repeat >> str("'")
        end
        rule(:double_string) { str('"') >> string_content >> str('"') }
        rule(:string_part) { (single_string | double_string).as(:string) }

        rule(:string_value) do
          string_part >> (whitespace? >> string_part).repeat
        end

        # String = STRING, { STRING } - multiple strings concatenate

        # Numeric literals
        rule(:sign) { match["+-"] }
        rule(:dec_lit) { (str("0") | (match["1-9"] >> dec.repeat)) }
        rule(:exp) { match["Ee"] >> sign.maybe >> dec.repeat(1) }
        rule(:float_lit) do
          (str(".") >> dec.repeat(1) >> exp.maybe) |
            (dec_lit >> str(".") >> dec.repeat >> exp.maybe) |
            (dec_lit >> exp)
        end

        rule(:dec_int) { dec_lit.as(:integer) }
        rule(:oct_int) { (str("0") >> oct.repeat(1)).as(:integer) }
        rule(:hex_int) do
          (str("0") >> match["Xx"] >> hex.repeat(1)).as(:integer)
        end
        rule(:float_token) do
          ((float_lit >> match["Ff"].maybe) | (dec_lit >> match["Ff"])).as(:float)
        end

        # Numbers - with optional sign
        rule(:signed_number) do
          str("-") >> whitespace? >> (float_token | hex_int | oct_int | dec_int)
        end
        rule(:unsigned_number) { float_token | hex_int | oct_int | dec_int }
        rule(:number) { signed_number | unsigned_number }

        # ===== Syntax Elements =====

        # Scalar values (not message blocks)
        rule(:scalar_value) do
          string_value | number | identifier | scalar_list
        end

        # Lists
        rule(:scalar_list) do
          str("[") >> whitespace? >>
            (scalar_value >> (whitespace? >> str(",") >> whitespace? >> scalar_value).repeat).maybe.as(:list) >>
            whitespace? >> str("]")
        end

        rule(:message_list) do
          str("[") >> whitespace? >>
            (message_value >> (whitespace? >> str(",") >> whitespace? >> message_value).repeat).maybe.as(:list) >>
            whitespace? >> str("]")
        end

        # Message value: { fields } or < fields >
        rule(:message_value) do
          ((str("{") >> whitespace? >> message >> whitespace? >> str("}")) |
           (str("<") >> whitespace? >> message >> whitespace? >> str(">"))).as(:message)
        end

        # Field names
        rule(:field_name) { identifier.as(:field_name) }

        # Fields - following official spec
        # ScalarField: field_name ":" scalar_value
        rule(:scalar_field) do
          field_name >>
            whitespace? >> str(":") >> whitespace? >>
            scalar_value.as(:field_value) >>
            whitespace? >> (str(";") | str(",")).maybe
        end

        # MessageField: field_name [":" ] (message_value | message_list)
        rule(:message_field) do
          field_name >>
            (whitespace? >> str(":")).maybe >> whitespace? >>
            (message_value | message_list).as(:field_value) >>
            whitespace? >> (str(";") | str(",")).maybe
        end

        # Any field type
        rule(:field) do
          whitespace? >> (message_field | scalar_field).as(:field) >> whitespace?
        end

        # Message = { Field }
        rule(:message) { field.repeat }

        # Document root
        rule(:document) { whitespace? >> message >> whitespace? }

        root(:document)
      end
    end
  end
end
