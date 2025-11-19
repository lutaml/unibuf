# frozen_string_literal: true

require "parslet"

module Unibuf
  module Parsers
    module Flatbuffers
      # Parslet grammar for parsing FlatBuffers schema definitions
      # Reference: https://flatbuffers.dev/flatbuffers_grammar.html
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

        # Numbers (including negative)
        rule(:number) do
          (match["+-"].maybe >> digit.repeat(1) >>
           (str(".") >> digit.repeat(1)).maybe).as(:number)
        end

        # Boolean literals
        rule(:bool_literal) do
          (str("true") | str("false")).as(:bool)
        end

        # ===== Syntax Elements =====

        # Namespace declaration: namespace com.example.game;
        rule(:namespace_stmt) do
          str("namespace") >> whitespace >>
            identifier.as(:namespace) >>
            (str(".") >> identifier).repeat >> whitespace? >> str(";")
        end

        # Include statement: include "other.fbs";
        rule(:include_stmt) do
          str("include") >> whitespace >>
            string_literal.as(:include) >> whitespace? >> str(";")
        end

        # Attribute: (id: 1, deprecated)
        rule(:attribute) do
          identifier.as(:name) >>
            (whitespace? >> str(":") >> whitespace? >>
             (number | bool_literal | string_literal | identifier).as(:value)).maybe
        end

        rule(:metadata) do
          str("(") >> whitespace? >>
            attribute.as(:attr) >>
            (whitespace? >> str(",") >> whitespace? >> attribute.as(:attr)).repeat >>
            whitespace? >> str(")")
        end

        # Scalar types
        rule(:scalar_type) do
          (str("byte") | str("ubyte") | str("short") | str("ushort") |
           str("int") | str("uint") | str("long") | str("ulong") |
           str("float") | str("double") | str("bool") | str("string")).as(:scalar_type)
        end

        # Vector type: [type]
        rule(:vector_type) do
          str("[") >> whitespace? >>
            (scalar_type | identifier.as(:user_type)) >>
            whitespace? >> str("]")
        end

        # Field type
        rule(:field_type) do
          vector_type.as(:vector) | scalar_type | identifier.as(:user_type)
        end

        # Default value
        rule(:default_value) do
          whitespace? >> str("=") >> whitespace? >>
            (number | bool_literal | string_literal | identifier.as(:enum_value)).as(:default)
        end

        # Table field: name: type = default (metadata);
        rule(:table_field) do
          identifier.as(:name) >> whitespace? >> str(":") >> whitespace? >>
            field_type.as(:type) >>
            default_value.maybe >>
            (whitespace? >> metadata.as(:metadata)).maybe >>
            whitespace? >> str(";")
        end

        # Table definition
        rule(:table_body) do
          (table_field.as(:field) | whitespace).repeat
        end

        rule(:table_def) do
          str("table") >> whitespace >>
            identifier.as(:table_name) >>
            (whitespace? >> metadata.as(:metadata)).maybe >>
            whitespace? >> str("{") >> whitespace? >>
            table_body.as(:body) >> whitespace? >>
            str("}")
        end

        # Struct definition (similar to table but fixed size)
        rule(:struct_field) do
          identifier.as(:name) >> whitespace? >> str(":") >> whitespace? >>
            field_type.as(:type) >>
            (whitespace? >> metadata.as(:metadata)).maybe >>
            whitespace? >> str(";")
        end

        rule(:struct_body) do
          (struct_field.as(:field) | whitespace).repeat
        end

        rule(:struct_def) do
          str("struct") >> whitespace >>
            identifier.as(:struct_name) >>
            (whitespace? >> metadata.as(:metadata)).maybe >>
            whitespace? >> str("{") >> whitespace? >>
            struct_body.as(:body) >> whitespace? >>
            str("}")
        end

        # Enum definition
        rule(:enum_value) do
          identifier.as(:name) >>
            (whitespace? >> str("=") >> whitespace? >> number.as(:value)).maybe >>
            whitespace? >> (str(",") | str(";")).maybe
        end

        rule(:enum_type) do
          whitespace? >> str(":") >> whitespace? >> scalar_type.as(:enum_type)
        end

        rule(:enum_def) do
          str("enum") >> whitespace >>
            identifier.as(:enum_name) >>
            enum_type.maybe >>
            (whitespace? >> metadata.as(:metadata)).maybe >>
            whitespace? >> str("{") >> whitespace? >>
            (enum_value.as(:value) >> whitespace?).repeat.as(:values) >>
            whitespace? >> str("}")
        end

        # Union definition
        rule(:union_value) do
          identifier.as(:type) >> whitespace? >> (str(",") | str(";")).maybe
        end

        rule(:union_def) do
          str("union") >> whitespace >>
            identifier.as(:union_name) >>
            (whitespace? >> metadata.as(:metadata)).maybe >>
            whitespace? >> str("{") >> whitespace? >>
            (union_value.as(:type) >> whitespace?).repeat.as(:types) >>
            whitespace? >> str("}")
        end

        # Root type declaration: root_type Monster;
        rule(:root_type_stmt) do
          str("root_type") >> whitespace >>
            identifier.as(:root_type) >> whitespace? >> str(";")
        end

        # File identifier: file_identifier "ABCD";
        rule(:file_identifier_stmt) do
          str("file_identifier") >> whitespace >>
            string_literal.as(:file_identifier) >> whitespace? >> str(";")
        end

        # File extension: file_extension "dat";
        rule(:file_extension_stmt) do
          str("file_extension") >> whitespace >>
            string_literal.as(:file_extension) >> whitespace? >> str(";")
        end

        # Attribute declaration: attribute "id";
        rule(:attribute_decl) do
          str("attribute") >> whitespace >>
            string_literal.as(:attribute) >> whitespace? >> str(";")
        end

        # Top-level elements
        rule(:fbs_element) do
          namespace_stmt.as(:namespace) |
            include_stmt.as(:include) |
            table_def.as(:table) |
            struct_def.as(:struct) |
            enum_def.as(:enum) |
            union_def.as(:union) |
            root_type_stmt.as(:root_type) |
            file_identifier_stmt.as(:file_identifier) |
            file_extension_stmt.as(:file_extension) |
            attribute_decl.as(:attribute_decl) |
            whitespace
        end

        # FlatBuffers schema file
        rule(:fbs_file) do
          whitespace? >> fbs_element.repeat >> whitespace?
        end

        root(:fbs_file)
      end
    end
  end
end
