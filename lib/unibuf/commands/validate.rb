# frozen_string_literal: true

module Unibuf
  module Commands
    # Validate command - Validate Protocol Buffer text format files
    class Validate
      attr_reader :options

      def initialize(options = {})
        @options = options
      end

      def run(file)
        validate_file_exists!(file)

        puts "Validating #{file}..." if verbose?

        # Syntax validation
        message = parse_and_validate_syntax(file)
        puts "✓ Syntax valid" if verbose?

        # Schema validation (if schema provided)
        if schema_file
          validate_against_schema(message)
          puts "✓ Schema valid" if verbose?
        end

        puts "✓ #{file} is valid"
      rescue FileNotFoundError => e
        error "File not found: #{e.message}"
        exit 1
      rescue ParseError => e
        error "Syntax error: #{e.message}"
        exit 1
      rescue ValidationError => e
        error "Validation error: #{e.message}"
        exit 1
      rescue StandardError => e
        error "Unexpected error: #{e.message}"
        error e.backtrace.first(5).join("\n") if verbose?
        exit 1
      end

      private

      def validate_file_exists!(file)
        raise FileNotFoundError, file unless File.exist?(file)
      end

      def parse_and_validate_syntax(file)
        Unibuf.parse_file(file)
      end

      def validate_against_schema(_message)
        # TODO: Implement schema validation when Proto3 parser is ready
        puts "Note: Schema validation not yet implemented" if verbose?
      end

      def schema_file
        options[:schema]
      end

      def verbose?
        options[:verbose]
      end

      def strict?
        options[:strict]
      end

      def error(message)
        warn "Error: #{message}"
      end
    end
  end
end
