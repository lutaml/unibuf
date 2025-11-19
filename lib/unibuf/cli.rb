# frozen_string_literal: true

require "thor"
require_relative "commands/parse"
require_relative "commands/validate"
require_relative "commands/convert"
require_relative "commands/schema"

module Unibuf
  # Command-line interface using Thor
  class Cli < Thor
    # Exit with error code on command failures
    def self.exit_on_failure?
      true
    end

    desc "parse FILE --schema SCHEMA",
         "Parse a Protocol Buffer file with schema"
    long_desc <<~DESC
      Parse a Protocol Buffer file (text or binary) using a schema.
      The schema defines the message structure and is REQUIRED.

      Text format:
        unibuf parse data.txtpb --schema schema.proto --format json

      Binary format:
        unibuf parse data.binpb --schema schema.proto --format json

      Auto-detect format:
        unibuf parse data.pb --schema schema.proto --format json
    DESC
    method_option :schema, type: :string, aliases: "-s", required: true,
                           desc: "Proto3 schema file (.proto) - REQUIRED"
    method_option :message_type, type: :string, aliases: "-t",
                                 desc: "Message type name (default: auto-detect from schema)"
    method_option :output, type: :string, aliases: "-o",
                           desc: "Output file path"
    method_option :format, type: :string, default: "json",
                           desc: "Output format (json, yaml, textproto)"
    method_option :input_format, type: :string,
                                 desc: "Input format (text, binary, auto)"
    method_option :verbose, type: :boolean,
                            desc: "Enable verbose output"
    def parse(file)
      Unibuf::Commands::Parse.new(options).run(file)
    end

    desc "validate FILE --schema SCHEMA",
         "Validate Protocol Buffer against schema"
    long_desc <<~DESC
      Validate Protocol Buffer file (text or binary) against its schema.
      The schema is REQUIRED to know what message type to validate.

      Examples:
        unibuf validate data.txtpb --schema schema.proto
        unibuf validate data.binpb --schema schema.proto
        unibuf validate data.pb --schema schema.proto --message-type FamilyProto
    DESC
    method_option :schema, type: :string, aliases: "-s", required: true,
                           desc: "Proto3 schema file - REQUIRED"
    method_option :message_type, type: :string, aliases: "-t",
                                 desc: "Message type name (default: first message in schema)"
    method_option :input_format, type: :string,
                                 desc: "Input format (text, binary, auto)"
    method_option :strict, type: :boolean,
                           desc: "Enable strict validation"
    method_option :verbose, type: :boolean,
                            desc: "Enable verbose output"
    def validate(file)
      Unibuf::Commands::Validate.new(options).run(file)
    end

    desc "convert FILE --schema SCHEMA",
         "Convert Protocol Buffer between formats"
    long_desc <<~DESC
      Convert Protocol Buffer between formats with schema validation.
      Schema is REQUIRED to understand the data structure.

      Text to JSON:
        unibuf convert data.txtpb --schema schema.proto --to json

      Binary to text:
        unibuf convert data.binpb --schema schema.proto --to txtpb

      Text to binary:
        unibuf convert data.txtpb --schema schema.proto --to binpb
    DESC
    method_option :schema, type: :string, aliases: "-s", required: true,
                           desc: "Schema file - REQUIRED"
    method_option :to, type: :string, required: true,
                       desc: "Target format (json, yaml, txtpb, binpb)"
    method_option :message_type, type: :string, aliases: "-t",
                                 desc: "Message type name"
    method_option :input_format, type: :string,
                                 desc: "Input format (text, binary, auto)"
    method_option :output, type: :string, aliases: "-o",
                           desc: "Output file path"
    method_option :verbose, type: :boolean,
                            desc: "Enable verbose output"
    def convert(file)
      Unibuf::Commands::Convert.new(options).run(file)
    end

    desc "schema FILE", "Parse and display Proto3 or FlatBuffers schema"
    long_desc <<~DESC
      Parse a schema file (.proto or .fbs) and display its structure.
      This shows you what message types are available in the schema.

      Examples:
        unibuf schema schema.proto
        unibuf schema schema.fbs --format json
    DESC
    method_option :format, type: :string, default: "text",
                           desc: "Output format (text, json, yaml)"
    method_option :output, type: :string, aliases: "-o",
                           desc: "Output file path"
    method_option :verbose, type: :boolean,
                            desc: "Enable verbose output"
    def schema(file)
      Unibuf::Commands::Schema.new(options).run(file)
    end

    desc "version", "Show Unibuf version"
    def version
      puts "Unibuf version #{Unibuf::VERSION}"
    end
  end
end
