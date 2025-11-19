# frozen_string_literal: true

require "parslet"

module Unibuf
  module Parsers
    module Proto3
      # Parslet grammar for parsing Proto3 schema definitions
      # Reference: https://protobuf.dev/reference/protobuf/proto3-spec/
      class Grammar < Parslet::Parser
        # ===== Lexical Elements =====

        # Whitespace and comments
        rule(:space) { match['\s'].repeat(1) }
        rule(:space?) { space.maybe }
        rule(:newline) { str("\n") }

        # Comments (// and /* */)
        rule(:line_comment) do
          str("//") >> (newline.absent? >> any).repeat >> newline.maybe
        end
        rule(:block_comment) do
          str("/*") >> (str("*/").absent? >> any).repeat >> str("*/")
        end
        rule(:comment) { line_comment | block_comment }

        rule(:whitespace) { (space | comment).repeat(1) }
        rule(:whitespace?) { (space | comment).repeat }

        # Identifiers
        rule(:letter) { match["a-zA-Z_"] }
        rule(:digit) { match["0-9"] }
        rule(:identifier) do
          (letter >> (letter | digit).repeat).as(:identifier)
        end

        # Strings
        rule(:string_content) { (str('"').absent? >> any).repeat }
        rule(:string_literal) do
          str('"') >> string_content.as(:string) >> str('"')
        end

        # Numbers
        rule(:number) { (match["+-"].maybe >> digit.repeat(1)).as(:number) }

        # ===== Syntax Elements =====

        # Syntax declaration: syntax = "proto3";
        rule(:syntax_stmt) do
          str("syntax") >> whitespace? >> str("=") >> whitespace? >>
            string_literal.as(:syntax_version) >> whitespace? >> str(";")
        end

        # Package declaration: package google.fonts;
        rule(:package_stmt) do
          str("package") >> whitespace? >>
            identifier.as(:package) >>
            (str(".") >> identifier).repeat >> whitespace? >> str(";")
        end

        # Import statement: import "other.proto";
        rule(:import_stmt) do
          str("import") >> whitespace? >>
            string_literal.as(:import) >> whitespace? >> str(";")
        end

        # Field types
        rule(:scalar_type) do
          (str("double") | str("float") | str("int32") | str("int64") |
           str("uint32") | str("uint64") | str("sint32") | str("sint64") |
           str("fixed32") | str("fixed64") | str("sfixed32") | str("sfixed64") |
           str("bool") | str("string") | str("bytes")).as(:scalar_type)
        end

        rule(:message_type) { identifier.as(:message_type) }
        rule(:field_type) { scalar_type | message_type }

        # Field definition: string name = 1;
        rule(:field_def) do
          (str("repeated") >> whitespace).maybe.as(:repeated) >>
            field_type.as(:type) >> whitespace >>
            identifier.as(:name) >> whitespace? >>
            str("=") >> whitespace? >>
            number.as(:field_number) >> whitespace? >>
            str(";")
        end

        # Map field: map<string, int32> mapping = 1;
        rule(:map_field) do
          str("map") >> whitespace? >> str("<") >> whitespace? >>
            field_type.as(:key_type) >> whitespace? >>
            str(",") >> whitespace? >>
            field_type.as(:value_type) >> whitespace? >>
            str(">") >> whitespace >>
            identifier.as(:name) >> whitespace? >>
            str("=") >> whitespace? >>
            number.as(:field_number) >> whitespace? >>
            str(";")
        end

        # Message definition
        rule(:message_body) do
          (field_def.as(:field) | map_field.as(:map_field) | message_def.as(:nested_message) | whitespace).repeat
        end

        rule(:message_def) do
          str("message") >> whitespace >>
            identifier.as(:message_name) >> whitespace? >>
            str("{") >> whitespace? >>
            message_body.as(:body) >> whitespace? >>
            str("}")
        end

        # Enum definition
        rule(:enum_value) do
          identifier.as(:name) >> whitespace? >>
            str("=") >> whitespace? >>
            number.as(:value) >> whitespace? >>
            str(";")
        end

        rule(:enum_def) do
          str("enum") >> whitespace >>
            identifier.as(:enum_name) >> whitespace? >>
            str("{") >> whitespace? >>
            enum_value.repeat.as(:values) >> whitespace? >>
            str("}")
        end

        # Top-level elements
        rule(:proto_element) do
          syntax_stmt.as(:syntax) |
            package_stmt.as(:package) |
            import_stmt.as(:import) |
            message_def.as(:message) |
            enum_def.as(:enum) |
            whitespace
        end

        # Proto file
        rule(:proto_file) do
          whitespace? >> proto_element.repeat >> whitespace?
        end

        root(:proto_file)
      end
    end
  end
end
