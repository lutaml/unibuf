# frozen_string_literal: true

require_relative "unibuf/version"
require_relative "unibuf/errors"

module Unibuf
  # Module for all parsers
  module Parsers
    # Text format parser
    module Textproto
    end

    # Proto3 schema parser
    module Proto3
    end

    # Binary Protocol Buffer parser
    module Binary
    end

    # FlatBuffers schema parser
    module Flatbuffers
    end
  end

  # Module for all models
  module Models
  end

  # Module for validators
  module Validators
  end

  # Module for serializers
  module Serializers
  end

  class << self
    # ===== TEXT FORMAT PARSING (no schema required) =====

    # Parse Protocol Buffer text format from string
    # @param content [String] Text format content
    # @return [Models::Message] Parsed message
    def parse_textproto(content)
      require_relative "unibuf/parsers/textproto/parser"
      Parsers::Textproto::Parser.new.parse(content)
    end
    alias parse_text parse_textproto
    alias parse_txtpb parse_textproto

    # Parse Protocol Buffer text format from file
    # @param path [String] Path to text format file
    # @return [Models::Message] Parsed message
    def parse_textproto_file(path)
      require_relative "unibuf/parsers/textproto/parser"
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

      require_relative "unibuf/parsers/binary/wire_format_parser"
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
      require_relative "unibuf/parsers/proto3/grammar"
      require_relative "unibuf/parsers/proto3/processor"

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
      require_relative "unibuf/parsers/flatbuffers/grammar"
      require_relative "unibuf/parsers/flatbuffers/processor"

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

      require_relative "unibuf/parsers/flatbuffers/binary_parser"
      Parsers::Flatbuffers::BinaryParser.new(schema).parse(content)
    end

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
