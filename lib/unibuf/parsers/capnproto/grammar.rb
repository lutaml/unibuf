# frozen_string_literal: true

require "parslet"

module Unibuf
  module Parsers
    module Capnproto
      # Parslet grammar for parsing Cap'n Proto schema definitions
      # Reference: https://capnproto.org/language.html
      class Grammar < Parslet::Parser
        # ===== Lexical Elements =====

        # Whitespace and comments
        rule(:space) { match['\s'].repeat(1) }
        rule(:space?) { space.maybe }
        rule(:newline) { str("\n") }

        # Comments (# style, different from Proto3)
        rule(:line_comment) do
          str("#") >> (newline.absent? >> any).repeat >> newline.maybe
        end
        rule(:comment) { line_comment }

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

        # Numbers (including hex for file IDs)
        rule(:hex_digit) { match["0-9a-fA-F"] }
        rule(:hex_number) do
          str("0x") >> hex_digit.repeat(1)
        end
        rule(:decimal_number) do
          match["+-"].maybe >> digit.repeat(1) >>
            (str(".") >> digit.repeat(1)).maybe
        end
        rule(:number) { (hex_number | decimal_number).as(:number) }

        # Boolean literals
        rule(:bool_literal) do
          (str("true") | str("false")).as(:bool)
        end

        # ===== File-Level Elements =====

        # File ID: @0x...;
        rule(:file_id) do
          str("@") >> hex_number.as(:number) >> whitespace? >> str(";")
        end

        # using declaration: using Foo = import "foo.capnp";
        rule(:using_stmt) do
          str("using") >> whitespace >>
            identifier.as(:alias) >> whitespace? >>
            str("=") >> whitespace? >>
            str("import") >> whitespace >>
            string_literal.as(:import_path) >> whitespace? >>
            str(";")
        end

        # Annotation: $annotation or $annotation(value)
        rule(:annotation_value) do
          str("(") >> whitespace? >>
            (number | bool_literal | string_literal | identifier).as(:value) >>
            whitespace? >> str(")")
        end

        rule(:annotation) do
          str("$") >> identifier.as(:annotation) >>
            annotation_value.maybe
        end

        # ===== Type System =====

        # Primitive types
        rule(:primitive_type) do
          (str("Void") | str("Bool") |
           str("Int8") | str("Int16") | str("Int32") | str("Int64") |
           str("UInt8") | str("UInt16") | str("UInt32") | str("UInt64") |
           str("Float32") | str("Float64") |
           str("Text") | str("Data") |
           str("AnyPointer")).as(:primitive_type)
        end

        # Generic type: List(T)
        rule(:generic_type) do
          str("List") >> whitespace? >>
            str("(") >> whitespace? >>
            field_type.as(:element_type) >>
            whitespace? >> str(")")
        end

        # Field type
        rule(:field_type) do
          generic_type.as(:generic) |
            primitive_type |
            identifier.as(:user_type)
        end

        # ===== Struct Definition =====

        # Field definition: name @ordinal :Type;
        rule(:field_def) do
          identifier.as(:name) >> whitespace? >>
            str("@") >> number.as(:ordinal) >> whitespace? >>
            str(":") >> whitespace? >>
            field_type.as(:type) >>
            (whitespace? >> str("=") >> whitespace? >>
             (number | bool_literal | string_literal).as(:default)).maybe >>
            whitespace? >> str(";")
        end

        # Union within struct: union { field1 @0 :Text; field2 @1 :Int32; }
        rule(:union_body) do
          (field_def.as(:field) | whitespace).repeat
        end

        rule(:union_def) do
          str("union") >> whitespace? >>
            str("{") >> whitespace? >>
            union_body.as(:fields) >> whitespace? >>
            str("}")
        end

        # Group: group { field @0 :Text; }
        rule(:group_body) do
          (field_def.as(:field) | whitespace).repeat
        end

        rule(:group_def) do
          identifier.as(:name) >> whitespace? >>
            str("@") >> number.as(:ordinal) >> whitespace? >>
            str(":group") >> whitespace? >>
            str("{") >> whitespace? >>
            group_body.as(:fields) >> whitespace? >>
            str("}")
        end

        # Struct body
        rule(:struct_element) do
          field_def.as(:field) |
            union_def.as(:union) |
            group_def.as(:group) |
            struct_def.as(:nested_struct) |
            enum_def.as(:nested_enum) |
            interface_def.as(:nested_interface) |
            whitespace
        end

        rule(:struct_body) do
          struct_element.repeat
        end

        rule(:struct_def) do
          (annotation.as(:annotation) >> whitespace?).repeat >>
            str("struct") >> whitespace >>
            identifier.as(:struct_name) >> whitespace? >>
            str("{") >> whitespace? >>
            struct_body.as(:body) >> whitespace? >>
            str("}")
        end

        # ===== Enum Definition =====

        # Enum value: name @ordinal;
        rule(:enum_value) do
          identifier.as(:name) >> whitespace? >>
            str("@") >> number.as(:ordinal) >> whitespace? >>
            str(";") >> whitespace?
        end

        rule(:enum_def) do
          (annotation.as(:annotation) >> whitespace?).repeat >>
            str("enum") >> whitespace >>
            identifier.as(:enum_name) >> whitespace? >>
            str("{") >> whitespace? >>
            enum_value.repeat(1).as(:values) >> whitespace? >>
            str("}")
        end

        # ===== Interface Definition (RPC) =====

        # Method parameter: name :Type
        rule(:param) do
          identifier.as(:name) >> whitespace? >>
            str(":") >> whitespace? >>
            field_type.as(:type)
        end

        rule(:param_list) do
          (param.as(:param) >>
           (whitespace? >> str(",") >> whitespace? >>
            param.as(:param)).repeat).maybe
        end

        # Method definition: methodName @ordinal (params) -> (results);
        rule(:method_def) do
          identifier.as(:name) >> whitespace? >>
            str("@") >> number.as(:ordinal) >> whitespace? >>
            str("(") >> whitespace? >>
            param_list.as(:params) >> whitespace? >>
            str(")") >> whitespace? >>
            (str("->") >> whitespace? >>
             str("(") >> whitespace? >>
             param_list.as(:results) >> whitespace? >>
             str(")")).maybe >> whitespace? >>
            str(";")
        end

        rule(:interface_body) do
          (method_def.as(:method) | whitespace).repeat
        end

        rule(:interface_def) do
          (annotation.as(:annotation) >> whitespace?).repeat >>
            str("interface") >> whitespace >>
            identifier.as(:interface_name) >> whitespace? >>
            str("{") >> whitespace? >>
            interface_body.as(:body) >> whitespace? >>
            str("}")
        end

        # ===== Const Definition =====

        rule(:const_value) do
          number | bool_literal | string_literal | identifier.as(:ref)
        end

        rule(:const_def) do
          str("const") >> whitespace >>
            identifier.as(:name) >> whitespace? >>
            str(":") >> whitespace? >>
            field_type.as(:type) >> whitespace? >>
            str("=") >> whitespace? >>
            const_value.as(:value) >> whitespace? >>
            str(";")
        end

        # ===== Top-Level Elements =====

        rule(:capnp_element) do
          file_id.as(:file_id) |
            using_stmt.as(:using) |
            const_def.as(:const) |
            struct_def.as(:struct) |
            enum_def.as(:enum) |
            interface_def.as(:interface) |
            whitespace
        end

        # Cap'n Proto file
        rule(:capnp_file) do
          whitespace? >> capnp_element.repeat >> whitespace?
        end

        root(:capnp_file)
      end
    end
  end
end
