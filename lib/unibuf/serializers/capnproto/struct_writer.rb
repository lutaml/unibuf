# frozen_string_literal: true

require_relative "segment_builder"
require_relative "pointer_encoder"

module Unibuf
  module Serializers
    module Capnproto
      # Writer for Cap'n Proto struct data
      # Writes data section (primitives) and pointer section (references)
      class StructWriter
        attr_reader :segment_builder, :segment_id, :word_offset, :data_words,
                    :pointer_words

        # Initialize struct writer
        # @param segment_builder [SegmentBuilder] Segment builder
        # @param segment_id [Integer] Segment ID
        # @param word_offset [Integer] Word offset in segment
        # @param data_words [Integer] Number of data words
        # @param pointer_words [Integer] Number of pointer words
        def initialize(segment_builder, segment_id, word_offset, data_words,
pointer_words)
          @segment_builder = segment_builder
          @segment_id = segment_id
          @word_offset = word_offset
          @data_words = data_words
          @pointer_words = pointer_words
        end

        # Write a primitive value to data section
        # @param word_index [Integer] Word index in data section
        # @param bit_offset [Integer] Bit offset within word (0-63)
        # @param bit_width [Integer] Width in bits
        # @param value [Integer] Value to write
        def write_data_field(word_index, bit_offset, bit_width, value)
          return if word_index >= @data_words

          # Read current word
          all_segments = @segment_builder.segments
          current = if @segment_id < all_segments.length
                      all_segments[@segment_id][@word_offset + word_index] || 0
                    else
                      0
                    end

          # Create mask and insert value
          mask = ((1 << bit_width) - 1) << bit_offset
          cleared = current & ~mask
          new_value = cleared | ((value << bit_offset) & mask)

          @segment_builder.write_word(@segment_id, @word_offset + word_index,
                                      new_value)
        end

        # Write unsigned 8-bit integer
        def write_uint8(word_index, byte_offset, value)
          write_data_field(word_index, byte_offset * 8, 8, value & 0xFF)
        end

        # Write signed 8-bit integer
        def write_int8(word_index, byte_offset, value)
          unsigned = value.negative? ? value + 256 : value
          write_uint8(word_index, byte_offset, unsigned)
        end

        # Write unsigned 16-bit integer
        def write_uint16(word_index, half_word_offset, value)
          write_data_field(word_index, half_word_offset * 16, 16,
                           value & 0xFFFF)
        end

        # Write signed 16-bit integer
        def write_int16(word_index, half_word_offset, value)
          unsigned = value.negative? ? value + 65536 : value
          write_uint16(word_index, half_word_offset, unsigned)
        end

        # Write unsigned 32-bit integer
        def write_uint32(word_index, dword_offset, value)
          write_data_field(word_index, dword_offset * 32, 32,
                           value & 0xFFFFFFFF)
        end

        # Write signed 32-bit integer
        def write_int32(word_index, dword_offset, value)
          unsigned = value.negative? ? value + 4294967296 : value
          write_uint32(word_index, dword_offset, unsigned)
        end

        # Write unsigned 64-bit integer
        def write_uint64(word_index, value)
          @segment_builder.write_word(@segment_id, @word_offset + word_index,
                                      value & 0xFFFFFFFFFFFFFFFF)
        end

        # Write signed 64-bit integer
        def write_int64(word_index, value)
          unsigned = value.negative? ? value + 18446744073709551616 : value
          write_uint64(word_index, unsigned)
        end

        # Write 32-bit float
        def write_float32(word_index, dword_offset, value)
          bits = [value].pack("f").unpack1("L")
          write_uint32(word_index, dword_offset, bits)
        end

        # Write 64-bit float
        def write_float64(word_index, value)
          bits = [value].pack("d").unpack1("Q")
          write_uint64(word_index, bits)
        end

        # Write boolean
        def write_bool(word_index, bit_offset, value)
          write_data_field(word_index, bit_offset, 1, value ? 1 : 0)
        end

        # Write a pointer to pointer section
        # @param pointer_index [Integer] Pointer index in pointer section
        # @param pointer_word [Integer] Encoded pointer word
        def write_pointer(pointer_index, pointer_word)
          return if pointer_index >= @pointer_words

          pointer_word_offset = @word_offset + @data_words + pointer_index
          @segment_builder.write_word(@segment_id, pointer_word_offset,
                                      pointer_word)
        end

        # Get pointer position for offset calculations
        # @param pointer_index [Integer] Pointer index
        # @return [Integer] Absolute word offset of pointer
        def pointer_position(pointer_index)
          @word_offset + @data_words + pointer_index
        end
      end
    end
  end
end
