# frozen_string_literal: true

module Unibuf
  module Parsers
    module Capnproto
      # Reader for Cap'n Proto binary segments
      # Cap'n Proto uses word-aligned (8-byte) segments for memory management
      class SegmentReader
        WORD_SIZE = 8 # Cap'n Proto uses 8-byte words

        attr_reader :segments, :segment_count

        # Initialize with binary data
        # @param data [String] Binary data to read
        def initialize(data)
          @data = data
          @segments = []
          @segment_count = 0
          parse_segments
        end

        # Read a word (8 bytes) from a segment at given offset
        # @param segment_id [Integer] Segment index
        # @param word_offset [Integer] Word offset within segment
        # @return [Integer] 64-bit word value
        def read_word(segment_id, word_offset)
          if segment_id >= @segment_count
            raise ArgumentError,
                  "Invalid segment ID"
          end
          raise ArgumentError, "Invalid word offset" if word_offset.negative?

          segment = @segments[segment_id]
          byte_offset = word_offset * WORD_SIZE

          if byte_offset + WORD_SIZE > segment.size
            raise ArgumentError,
                  "Offset out of bounds"
          end

          # Read 8 bytes as little-endian 64-bit unsigned integer
          segment[byte_offset, WORD_SIZE].unpack1("Q<")
        end

        # Read multiple words from a segment
        # @param segment_id [Integer] Segment index
        # @param word_offset [Integer] Starting word offset
        # @param count [Integer] Number of words to read
        # @return [Array<Integer>] Array of word values
        def read_words(segment_id, word_offset, count)
          (0...count).map { |i| read_word(segment_id, word_offset + i) }
        end

        # Read bytes from a segment
        # @param segment_id [Integer] Segment index
        # @param byte_offset [Integer] Byte offset within segment
        # @param length [Integer] Number of bytes to read
        # @return [String] Binary data
        def read_bytes(segment_id, byte_offset, length)
          if segment_id >= @segment_count
            raise ArgumentError,
                  "Invalid segment ID"
          end

          segment = @segments[segment_id]
          if byte_offset + length > segment.size
            raise ArgumentError,
                  "Offset out of bounds"
          end

          segment[byte_offset, length]
        end

        # Get segment size in words
        # @param segment_id [Integer] Segment index
        # @return [Integer] Size in words
        def segment_size(segment_id)
          if segment_id >= @segment_count
            raise ArgumentError,
                  "Invalid segment ID"
          end

          @segments[segment_id].size / WORD_SIZE
        end

        # Check if a segment exists
        # @param segment_id [Integer] Segment index
        # @return [Boolean]
        def segment_exists?(segment_id)
          segment_id >= 0 && segment_id < @segment_count
        end

        private

        def parse_segments
          return if @data.nil? || @data.empty?

          # Read segment count (first 4 bytes as little-endian 32-bit integer)
          # Segment count: (N + 1) where N is in the first 4 bytes
          segment_count_minus_one = @data[0, 4].unpack1("L<")
          @segment_count = segment_count_minus_one + 1

          # Read segment sizes (each is a 4-byte little-endian integer)
          # Segment sizes start at byte 4
          offset = 4
          segment_sizes = []

          @segment_count.times do
            size = @data[offset, 4].unpack1("L<")
            segment_sizes << size
            offset += 4
          end

          # Align to 8-byte boundary after segment table
          # Header size is 4 + (segment_count * 4) = 4 * (1 + segment_count)
          # If segment count is ODD, header is divisible by 8 (no padding needed)
          # If segment count is EVEN, header needs 4 bytes padding to align to 8
          offset += 4 unless @segment_count.odd?

          # Read each segment
          segment_sizes.each do |size_in_words|
            size_in_bytes = size_in_words * WORD_SIZE
            segment_data = @data[offset, size_in_bytes]
            @segments << segment_data
            offset += size_in_bytes
          end
        end
      end
    end
  end
end
