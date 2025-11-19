# frozen_string_literal: true

module Unibuf
  module Commands
    # Parse command - Parse Protocol Buffer text format files
    class Parse
      attr_reader :options

      def initialize(options = {})
        @options = options
      end

      def run(file)
        validate_file!(file)

        puts "Parsing #{file}..." if verbose?

        message = parse_file(file)
        output_result(message)

        puts "✓ Successfully parsed #{file}" if verbose?
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

      def parse_file(file)
        Unibuf.parse_file(file)
      end

      def output_result(message)
        content = format_output(message)

        if output_file
          File.write(output_file, content)
          puts "Output written to #{output_file}" if verbose?
        else
          puts content
        end
      end

      def format_output(message)
        case output_format
        when "json"
          message.to_json
        when "yaml"
          message.to_yaml
        when "textproto"
          message.to_textproto
        else
          raise InvalidArgumentError, "Unknown format: #{output_format}"
        end
      end

      def output_file
        options[:output]
      end

      def output_format
        options[:format] || "json"
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
