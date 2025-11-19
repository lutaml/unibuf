# frozen_string_literal: true

module Unibuf
  module Commands
    # Convert command - Convert between Protocol Buffer formats
    class Convert
      attr_reader :options

      def initialize(options = {})
        @options = options
      end

      def run(file)
        validate_inputs!(file)

        puts "Converting #{file} to #{target_format}..." if verbose?

        message = load_message(file)
        converted = convert_message(message)
        write_output(converted)

        puts "✓ Converted successfully" if verbose?
      rescue FileNotFoundError => e
        error "File not found: #{e.message}"
        exit 1
      rescue InvalidArgumentError => e
        error "Invalid argument: #{e.message}"
        exit 1
      rescue StandardError => e
        error "Error: #{e.message}"
        error e.backtrace.first(5).join("\n") if verbose?
        exit 1
      end

      private

      def validate_inputs!(file)
        raise FileNotFoundError, file unless File.exist?(file)

        unless target_format
          raise InvalidArgumentError,
                "Target format required"
        end

        valid_formats = %w[json yaml textproto binpb]
        unless valid_formats.include?(target_format)
          raise InvalidArgumentError,
                "Invalid format '#{target_format}'. " \
                "Valid formats: #{valid_formats.join(', ')}"
        end

        # Binary format requires schema
        if target_format == "binpb" && !schema_file
          raise InvalidArgumentError,
                "Binary format requires --schema option"
        end

        # Binary input requires schema
        if binary_file?(file) && !schema_file
          raise InvalidArgumentError,
                "Binary input requires --schema option"
        end
      end

      def load_message(file)
        # Detect source format and parse appropriately
        if json_file?(file)
          load_from_json(file)
        elsif yaml_file?(file)
          load_from_yaml(file)
        elsif binary_file?(file)
          load_from_binary(file)
        else
          Unibuf.parse_file(file)
        end
      end

      def load_from_json(file)
        require "json"
        data = JSON.parse(File.read(file))
        Unibuf::Models::Message.from_hash(data)
      end

      def load_from_yaml(file)
        require "yaml"
        data = YAML.load_file(file)
        Unibuf::Models::Message.from_hash(data)
      end

      def load_from_binary(file)
        schema = load_schema
        Unibuf.parse_binary_file(file, schema: schema)
      end

      def convert_message(message)
        case target_format
        when "json"
          message.to_json
        when "yaml"
          message.to_yaml
        when "textproto"
          message.to_textproto
        when "binpb"
          schema = load_schema
          message.to_binary(schema: schema, message_type: message_type)
        end
      end

      def write_output(content)
        if output_file
          if target_format == "binpb"
            File.binwrite(output_file, content)
          else
            File.write(output_file, content)
          end
          puts "Output written to #{output_file}" if verbose?
        elsif target_format == "binpb"
          $stdout.binmode
          $stdout.write(content)
        # Binary output to stdout
        else
          puts content
        end
      end

      def load_schema
        return @schema if @schema

        unless schema_file
          raise InvalidArgumentError,
                "Schema required for binary format"
        end

        unless File.exist?(schema_file)
          raise FileNotFoundError,
                "Schema file not found: #{schema_file}"
        end

        @schema = Unibuf.parse_schema(schema_file)
      end

      def json_file?(file)
        file.end_with?(".json")
      end

      def yaml_file?(file)
        file.end_with?(".yaml", ".yml")
      end

      def binary_file?(file)
        file.end_with?(".binpb", ".bin", ".pb")
      end

      def target_format
        options[:to]
      end

      def output_file
        options[:output]
      end

      def schema_file
        options[:schema]
      end

      def message_type
        options[:message_type]
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
