# frozen_string_literal: true

module Unibuf
  module Parsers
    module Binary
      # Binary Protocol Buffer wire format parser
      # Requires bindata gem for implementation
      #
      # TODO: Implement wire format parsing using bindata
      # Reference: https://protobuf.dev/programming-guides/encoding/
      class WireFormatParser
        attr_reader :schema

        def initialize(schema)
          @schema = schema
        end

        def parse(binary_data)
          raise NotImplementedError, <<~MSG
            Binary Protocol Buffer parsing not yet implemented.

            This feature requires:
            1. bindata gem integration
            2. Wire format decoder
            3. Schema-driven field extraction
            4. Type deserialization

            Current implementation: Text format only
            Roadmap: Binary support in v2.0.0

            For now, use text format:
              Unibuf.parse_textproto(text_content)
              Unibuf.parse_textproto_file("file.txtpb")
          MSG
        end

        def parse_file(path)
          parse(File.binread(path))
        end
      end
    end
  end
end
