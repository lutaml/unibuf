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

        valid_formats = %w[json yaml textproto]
        unless valid_formats.include?(target_format)
          raise InvalidArgumentError,
                "Invalid format '#{target_format}'. " \
                "Valid formats: #{valid_formats.join(', ')}"
        end
      end

      def load_message(file)
        # Detect source format and parse appropriately
        if json_file?(file)
          load_from_json(file)
        elsif yaml_file?(file)
          load_from_yaml(file)
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

      def convert_message(message)
        case target_format
        when "json"
          message.to_json
        when "yaml"
          message.to_yaml
        when "textproto"
          message.to_textproto
        end
      end

      def write_output(content)
        if output_file
          File.write(output_file, content)
          puts "Output written to #{output_file}" if verbose?
        else
          puts content
        end
      end

      def json_file?(file)
        file.end_with?(".json")
      end

      def yaml_file?(file)
        file.end_with?(".yaml", ".yml")
      end

      def target_format
        options[:to]
      end

      def output_file
        options[:output]
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
