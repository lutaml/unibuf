# frozen_string_literal: true

module Unibuf
  module Commands
    # Schema command - Parse and display schema files
    class Schema
      attr_reader :options

      def initialize(options = {})
        @options = options
      end

      def run(file)
        validate_file!(file)

        puts "Parsing schema #{file}..." if verbose?

        schema = parse_schema(file)
        output_result(schema)

        puts "✓ Successfully parsed schema" if verbose?
      rescue FileNotFoundError => e
        error "File not found: #{e.message}"
        exit 1
      rescue ParseError => e
        error "Parse error: #{e.message}"
        exit 1
      rescue StandardError => e
        error "Unexpected error: #{e.message}"
        error e.backtrace.first(5).join("\n") if verbose?
        exit 1
      end

      private

      def validate_file!(file)
        raise FileNotFoundError, file unless File.exist?(file)
      end

      def parse_schema(file)
        case File.extname(file)
        when ".proto"
          Unibuf.parse_schema(file)
        when ".fbs"
          Unibuf.parse_flatbuffers_schema(file)
        when ".capnp"
          Unibuf.parse_capnproto_schema(file)
        else
          raise InvalidArgumentError,
                "Unknown schema format: #{File.extname(file)}"
        end
      end

      def output_result(schema)
        content = format_output(schema)

        if output_file
          File.write(output_file, content)
          puts "Output written to #{output_file}" if verbose?
        else
          puts content
        end
      end

      def format_output(schema)
        case output_format
        when "json"
          require "json"
          schema.to_h.to_json
        when "yaml"
          require "yaml"
          schema.to_h.to_yaml
        when "text"
          format_text(schema)
        else
          raise InvalidArgumentError, "Unknown format: #{output_format}"
        end
      end

      def format_text(schema)
        lines = []

        # Handle different schema types
        if schema.respond_to?(:package)
          # Proto3 schema
          lines << "Package: #{schema.package}" if schema.package
          lines << "Syntax: #{schema.syntax}"
          lines << ""
          lines << "Messages (#{schema.messages.size}):"
          schema.messages.each do |msg|
            lines << "  #{msg.name} (#{msg.fields.size} fields)"
          end
          if schema.enums.any?
            lines << ""
            lines << "Enums (#{schema.enums.size}):"
            schema.enums.each do |enum|
              lines << "  #{enum.name} (#{enum.values.size} values)"
            end
          end
        elsif schema.respond_to?(:file_id)
          # Cap'n Proto schema
          lines << "File ID: #{schema.file_id}" if schema.file_id
          lines << ""
          if schema.structs.any?
            lines << "Structs (#{schema.structs.size}):"
            schema.structs.each do |struct|
              lines << "  #{struct.name} (#{struct.fields.size} fields)"
            end
          end
          if schema.enums.any?
            lines << ""
            lines << "Enums (#{schema.enums.size}):"
            schema.enums.each do |enum|
              lines << "  #{enum.name} (#{enum.values.size} values)"
            end
          end
          if schema.interfaces.any?
            lines << ""
            lines << "Interfaces (#{schema.interfaces.size}):"
            schema.interfaces.each do |interface|
              lines << "  #{interface.name} (#{interface.methods.size} methods)"
            end
          end
        else
          # FlatBuffers schema
          lines << "Namespace: #{schema.namespace}" if schema.namespace
          lines << "Root Type: #{schema.root_type}" if schema.root_type
          lines << ""
          if schema.tables.any?
            lines << "Tables (#{schema.tables.size}):"
            schema.tables.each do |table|
              lines << "  #{table.name} (#{table.fields.size} fields)"
            end
          end
          if schema.structs.any?
            lines << ""
            lines << "Structs (#{schema.structs.size}):"
            schema.structs.each do |struct|
              lines << "  #{struct.name} (#{struct.fields.size} fields)"
            end
          end
          if schema.enums.any?
            lines << ""
            lines << "Enums (#{schema.enums.size}):"
            schema.enums.each do |enum|
              lines << "  #{enum.name} (#{enum.values.size} values)"
            end
          end
        end

        lines.join("\n")
      end

      def output_file
        options[:output]
      end

      def output_format
        options[:format] || "text"
      end

      def verbose?
        options[:verbose]
      end

      def error(message)
        warn "Error: #{message}"
      end
    end
  end
end
