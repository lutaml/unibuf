# frozen_string_literal: true

require_relative "unibuf/version"
require_relative "unibuf/errors"

module Unibuf
  # Module for all parsers
  module Parsers
    # Text format parser
    module Textproto
      autoload :Grammar, "unibuf/parsers/textproto/grammar"
      autoload :Processor, "unibuf/parsers/textproto/processor"
      autoload :Parser, "unibuf/parsers/textproto/parser"
    end

    # Proto3 schema parser
    module Proto3
      autoload :Grammar, "unibuf/parsers/proto3/grammar"
      autoload :Processor, "unibuf/parsers/proto3/processor"
    end

    # Binary Protocol Buffer parser
    module Binary
      autoload :WireFormatParser, "unibuf/parsers/binary/wire_format_parser"
    end

    # FlatBuffers schema parser
    module Flatbuffers
      autoload :Grammar, "unibuf/parsers/flatbuffers/grammar"
      autoload :Processor, "unibuf/parsers/flatbuffers/processor"
      autoload :BinaryParser, "unibuf/parsers/flatbuffers/binary_parser"
    end

    # Cap'n Proto schema parser
    module Capnproto
      autoload :Grammar, "unibuf/parsers/capnproto/grammar"
      autoload :Processor, "unibuf/parsers/capnproto/processor"
      autoload :BinaryParser, "unibuf/parsers/capnproto/binary_parser"
      autoload :SegmentReader, "unibuf/parsers/capnproto/segment_reader"
      autoload :PointerDecoder, "unibuf/parsers/capnproto/pointer_decoder"
      autoload :StructReader, "unibuf/parsers/capnproto/struct_reader"
      autoload :ListReader, "unibuf/parsers/capnproto/list_reader"
    end
  end

  # Module for all models
  module Models
    autoload :Message, "unibuf/models/message"
    autoload :Field, "unibuf/models/field"
    autoload :Schema, "unibuf/models/schema"
    autoload :MessageDefinition, "unibuf/models/message_definition"
    autoload :FieldDefinition, "unibuf/models/field_definition"
    autoload :EnumDefinition, "unibuf/models/enum_definition"

    # FlatBuffers models
    module Flatbuffers
      autoload :Schema, "unibuf/models/flatbuffers/schema"
      autoload :TableDefinition, "unibuf/models/flatbuffers/table_definition"
      autoload :StructDefinition, "unibuf/models/flatbuffers/struct_definition"
      autoload :FieldDefinition, "unibuf/models/flatbuffers/field_definition"
      autoload :EnumDefinition, "unibuf/models/flatbuffers/enum_definition"
      autoload :UnionDefinition, "unibuf/models/flatbuffers/union_definition"
    end

    # Cap'n Proto models
    module Capnproto
      autoload :Schema, "unibuf/models/capnproto/schema"
      autoload :StructDefinition, "unibuf/models/capnproto/struct_definition"
      autoload :FieldDefinition, "unibuf/models/capnproto/field_definition"
      autoload :EnumDefinition, "unibuf/models/capnproto/enum_definition"
      autoload :InterfaceDefinition, "unibuf/models/capnproto/interface_definition"
      autoload :MethodDefinition, "unibuf/models/capnproto/method_definition"
      autoload :UnionDefinition, "unibuf/models/capnproto/union_definition"
    end

    # Value classes (nested under Values module)
    module Values
      autoload :BaseValue, "unibuf/models/values/base_value"
      autoload :ScalarValue, "unibuf/models/values/scalar_value"
      autoload :ListValue, "unibuf/models/values/list_value"
      autoload :MapValue, "unibuf/models/values/map_value"
      autoload :MessageValue, "unibuf/models/values/message_value"
    end
  end

  # Module for validators
  module Validators
    autoload :TypeValidator, "unibuf/validators/type_validator"
    autoload :SchemaValidator, "unibuf/validators/schema_validator"
  end

  # Module for serializers
  module Serializers
    autoload :BinarySerializer, "unibuf/serializers/binary_serializer"
  end

  class << self
    # ===== TEXT FORMAT PARSING (no schema required) =====

    # Parse Protocol Buffer text format from string
    # @param content [String] Text format content
    # @return [Models::Message] Parsed message
    def parse_textproto(content)
      Parsers::Textproto::Parser.new.parse(content)
    end
    alias parse_text parse_textproto
    alias parse_txtpb parse_textproto

    # Parse Protocol Buffer text format from file
    # @param path [String] Path to text format file
    # @return [Models::Message] Parsed message
    def parse_textproto_file(path)
      Parsers::Textproto::Parser.new.parse_file(path)
    end
    alias parse_text_file parse_textproto_file

    # ===== BINARY FORMAT PARSING (schema required) =====

    # Parse binary Protocol Buffer data
    # @param content [String] Binary data
    # @param schema [Models::Schema] Proto3 schema (required)
    # @return [Models::Message] Parsed message
    def parse_binary(content, schema:)
      raise ArgumentError, "Schema required for binary parsing" unless schema

      Parsers::Binary::WireFormatParser.new(schema).parse(content)
    end
    alias parse_binpb parse_binary

    # Parse binary Protocol Buffer file
    # @param path [String] Path to binary file
    # @param schema [Models::Schema] Proto3 schema (required)
    # @return [Models::Message] Parsed message
    def parse_binary_file(path, schema:)
      parse_binary(File.binread(path), schema: schema)
    end
    alias parse_binpb_file parse_binary_file

    # ===== SCHEMA PARSING =====

    # Parse Proto3 schema file
    # @param path [String] Path to .proto file
    # @return [Models::Schema] Schema object
    def parse_schema(path)
      grammar = Parsers::Proto3::Grammar.new
      content = File.read(path)
      ast = grammar.parse(content)
      Parsers::Proto3::Processor.process(ast)
    end
    alias load_schema parse_schema
    alias parse_proto3 parse_schema

    # ===== FLATBUFFERS =====

    # Parse FlatBuffers schema file
    # @param path [String] Path to .fbs file
    # @return [Models::Flatbuffers::Schema] FlatBuffers schema
    def parse_flatbuffers_schema(path)
      grammar = Parsers::Flatbuffers::Grammar.new
      content = File.read(path)
      ast = grammar.parse(content)
      Parsers::Flatbuffers::Processor.process(ast)
    end
    alias parse_fbs parse_flatbuffers_schema

    # Parse FlatBuffers binary data
    # @param content [String] Binary FlatBuffers data
    # @param schema [Models::Flatbuffers::Schema] FlatBuffers schema (required)
    # @return [Object] Parsed FlatBuffer object
    def parse_flatbuffers_binary(content, schema:)
      unless schema
        raise ArgumentError,
              "Schema required for FlatBuffers parsing"
      end

      Parsers::Flatbuffers::BinaryParser.new(schema).parse(content)
    end

    # ===== CAP'N PROTO =====

    # Parse Cap'n Proto schema file
    # @param path [String] Path to .capnp file
    # @return [Models::Capnproto::Schema] Cap'n Proto schema
    def parse_capnproto_schema(path)
      grammar = Parsers::Capnproto::Grammar.new
      content = File.read(path)
      ast = grammar.parse(content)
      Parsers::Capnproto::Processor.process(ast)
    end
    alias parse_capnp parse_capnproto_schema

    # ===== AUTO-DETECTION (convenience methods) =====

    # Auto-detect format and parse
    # @param path_or_content [String] File path or content
    # @param schema [Models::Schema, nil] Schema for binary formats (optional)
    # @return [Models::Message] Parsed message
    def parse(path_or_content, schema: nil)
      if File.exist?(path_or_content)
        parse_file(path_or_content, schema: schema)
      else
        # Assume text if no schema provided
        parse_textproto(path_or_content)
      end
    end

    # Parse file with format auto-detection
    # @param path [String] File path
    # @param schema [Models::Schema, nil] Schema for binary formats
    # @return [Models::Message] Parsed message
    def parse_file(path, schema: nil)
      case File.extname(path).downcase
      when ".txtpb", ".textproto"
        parse_textproto_file(path)
      when ".binpb"
        unless schema
          raise ArgumentError,
                "Binary format requires schema (use schema: parameter)"
        end

        parse_binary_file(path, schema: schema)
      when ".proto"
        raise ArgumentError, ".proto files are schemas, use parse_schema()"
      when ".fbs"
        raise ArgumentError,
              ".fbs files are schemas, use parse_flatbuffers_schema()"
      when ".capnp"
        raise ArgumentError,
              ".capnp files are schemas, use parse_capnproto_schema()"
      when ".pb"
        # Ambiguous extension - try to detect
        detect_and_parse_pb(path, schema)
      else
        # Try text format
        parse_textproto_file(path)
      end
    end

    private

    def detect_and_parse_pb(path, schema)
      content = File.binread(path)

      if binary_format?(content)
        unless schema
          raise ArgumentError,
                "Binary .pb requires schema parameter"
        end

        parse_binary(content, schema: schema)
      else
        # Text format
        parse_textproto(File.read(path))
      end
    end

    def binary_format?(content)
      # Binary Protocol Buffers have field tags in first few bytes
      # Text format starts with field names (letters)
      return false if content.empty?

      # Check first non-whitespace byte
      first_byte = content.bytes.find { |b| b > 32 }
      return false unless first_byte

      # Text starts with letters (65-90, 97-122) or # (35) for comments
      # Binary starts with field tags (usually 8-127 for small field numbers)
      return false if first_byte == 35 # # comment
      return false if first_byte.between?(65, 90) # A-Z
      return false if first_byte.between?(97, 122) # a-z

      # Likely binary
      true
    end
  end
end
