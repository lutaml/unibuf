# frozen_string_literal: true

module Unibuf
  module Serializers
    module Capnproto
      # Builder for Cap'n Proto binary segments
      # Manages segment allocation and word-aligned writes
      class SegmentBuilder
        WORD_SIZE = 8 # Cap'n Proto uses 8-byte words

        attr_reader :segments

        def initialize
          @segments = []
          @current_segment = []
          @current_segment_id = 0
        end

        # Get all segments including current
        def segments
          if @current_segment.empty?
            @segments
          else
            @segments + [@current_segment]
          end
        end

        # Allocate words in current segment
        # @param word_count [Integer] Number of words to allocate
        # @return [Array<Integer>] [segment_id, word_offset]
        def allocate(word_count)
          segment_id = @current_segment_id
          word_offset = @current_segment.length

          # Add placeholder words
          word_count.times { @current_segment << 0 }

          [segment_id, word_offset]
        end

        # Write a word at specific location
        # @param segment_id [Integer] Segment index
        # @param word_offset [Integer] Word offset within segment
        # @param value [Integer] 64-bit word value
        def write_word(segment_id, word_offset, value)
          if segment_id == @current_segment_id
            # Writing to current segment
            @current_segment[word_offset] = value & 0xFFFFFFFFFFFFFFFF
          elsif segment_id < @segments.length
            # Writing to finalized segment
            @segments[segment_id][word_offset] = value & 0xFFFFFFFFFFFFFFFF
          else
            raise "Invalid segment ID: #{segment_id}"
          end
        end

        # Write multiple words
        # @param segment_id [Integer] Segment index
        # @param word_offset [Integer] Starting word offset
        # @param values [Array<Integer>] Word values
        def write_words(segment_id, word_offset, values)
          values.each_with_index do |value, i|
            write_word(segment_id, word_offset + i, value)
          end
        end

        # Finalize current segment and start a new one
        def finalize_segment
          @segments << @current_segment unless @current_segment.empty?
          @current_segment = []
          @current_segment_id = @segments.length
        end

        # Build final binary output
        # @return [String] Binary data
        def build
          # Finalize current segment if not empty
          finalize_segment unless @current_segment.empty?

          return "" if @segments.empty?

          # Build segment table
          segment_count = @segments.length
          segment_sizes = @segments.map(&:length)

          # Segment table header
          output = [segment_count - 1].pack("L<") # segment count - 1

          # Segment sizes
          segment_sizes.each do |size|
            output += [size].pack("L<")
          end

          # Add padding if needed (when segment count is even)
          output += [0].pack("L<") unless segment_count.odd?

          # Write segment data
          @segments.each do |segment|
            segment.each do |word|
              output += [word].pack("Q<")
            end
          end

          output
        end

        # Get current position for relative offset calculation
        # @return [Array<Integer>] [segment_id, word_offset]
        def current_position
          [@current_segment_id, @current_segment.length]
        end

        private

        def ensure_segment(segment_id)
          return if segment_id == @current_segment_id
          return if segment_id < @segments.length

          raise "Invalid segment ID: #{segment_id}"
        end
      end
    end
  end
end
