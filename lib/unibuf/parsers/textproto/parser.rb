# frozen_string_literal: true

require_relative "grammar"
require_relative "processor"
require_relative "../../models/message"

module Unibuf
  module Parsers
    module Textproto
      # High-level parser for Protocol Buffers text format
      # Combines Grammar (Parslet) and Processor (manual transformation)
      class Parser
        attr_reader :grammar

        def initialize
          @grammar = Grammar.new
        end

        # Parse textproto content from a string
        # @param content [String] The textproto content
        # @return [Unibuf::Models::Message] The parsed message
        def parse(content)
          raise ArgumentError, "Content cannot be nil" if content.nil?
          raise ArgumentError, "Content cannot be empty" if content.empty?

          begin
            # Step 1: Parse with Parslet grammar -> AST
            ast = grammar.parse(content)

            # Step 2: Transform AST with Processor -> Hash
            hash = Processor.process(ast)

            # Step 3: Create domain model from hash
            Models::Message.new(hash)
          rescue Parslet::ParseFailed => e
            raise ParseError, format_parse_error(e, content)
          end
        end

        # Parse textproto from a file
        # @param path [String] Path to the textproto file
        # @return [Unibuf::Models::Message] The parsed message
        def parse_file(path)
          unless File.exist?(path)
            raise FileNotFoundError,
                  "File not found: #{path}"
          end

          begin
            content = File.read(path)
            parse(content)
          rescue Errno::ENOENT => e
            raise FileNotFoundError, "Cannot read file: #{path} - #{e.message}"
          rescue Errno::EACCES => e
            raise FileReadError, "Permission denied: #{path} - #{e.message}"
          rescue StandardError => e
            raise FileReadError, "Error reading file: #{path} - #{e.message}"
          end
        end

        private

        # Format Parslet parse error with context
        def format_parse_error(error, content)
          lines = content.lines
          line_no = error.parse_failure_cause.source.line_and_column[0]
          col_no = error.parse_failure_cause.source.line_and_column[1]

          context = []
          context << "Parse error at line #{line_no}, column #{col_no}:"
          context << ""

          # Show context lines
          start_line = [line_no - 2, 0].max
          end_line = [line_no + 2, lines.size - 1].min

          (start_line..end_line).each do |i|
            prefix = i == line_no - 1 ? "=> " : "   "
            context << "#{prefix}#{i + 1}: #{lines[i]}"
          end

          context << ""
          context << "#{' ' * (col_no + 7)}^"
          context << ""
          context << error.parse_failure_cause.to_s

          context.join("\n")
        end
      end
    end
  end
end
