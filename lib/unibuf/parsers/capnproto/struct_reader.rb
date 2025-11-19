# frozen_string_literal: true

require_relative "segment_reader"
require_relative "pointer_decoder"

module Unibuf
  module Parsers
    module Capnproto
      # Reader for Cap'n Proto struct data
      # Structs have two sections: data (inline primitives) and pointers
      class StructReader
        attr_reader :segment_reader, :segment_id, :word_offset, :data_words,
                    :pointer_words

        # Initialize struct reader
        # @param segment_reader [SegmentReader] Segment reader
        # @param segment_id [Integer] Segment containing the struct
        # @param word_offset [Integer] Word offset of struct start
        # @param data_words [Integer] Number of data words
        # @param pointer_words [Integer] Number of pointer words
        def initialize(segment_reader, segment_id, word_offset, data_words,
pointer_words)
          @segment_reader = segment_reader
          @segment_id = segment_id
          @word_offset = word_offset
          @data_words = data_words
          @pointer_words = pointer_words
        end

        # Read a primitive field from data section
        # @param word_index [Integer] Word index in data section
        # @param bit_offset [Integer] Bit offset within word (0-63)
        # @param bit_width [Integer] Width in bits
        # @return [Integer] Field value
        def read_data_field(word_index, bit_offset = 0, bit_width = 64)
          return 0 if word_index >= @data_words

          word = @segment_reader.read_word(@segment_id,
                                           @word_offset + word_index)

          # Extract bits
          mask = (1 << bit_width) - 1
          (word >> bit_offset) & mask
        end

        # Read an 8-bit integer
        # @param word_index [Integer] Word index
        # @param byte_offset [Integer] Byte offset within word (0-7)
        # @return [Integer]
        def read_int8(word_index, byte_offset = 0)
          value = read_data_field(word_index, byte_offset * 8, 8)
          # Convert to signed
          value >= 128 ? value - 256 : value
        end

        # Read an unsigned 8-bit integer
        # @param word_index [Integer] Word index
        # @param byte_offset [Integer] Byte offset within word (0-7)
        # @return [Integer]
        def read_uint8(word_index, byte_offset = 0)
          read_data_field(word_index, byte_offset * 8, 8)
        end

        # Read a 16-bit integer
        # @param word_index [Integer] Word index
        # @param half_word_offset [Integer] Half-word offset (0-3)
        # @return [Integer]
        def read_int16(word_index, half_word_offset = 0)
          value = read_data_field(word_index, half_word_offset * 16, 16)
          # Convert to signed
          value >= 32768 ? value - 65536 : value
        end

        # Read an unsigned 16-bit integer
        # @param word_index [Integer] Word index
        # @param half_word_offset [Integer] Half-word offset (0-3)
        # @return [Integer]
        def read_uint16(word_index, half_word_offset = 0)
          read_data_field(word_index, half_word_offset * 16, 16)
        end

        # Read a 32-bit integer
        # @param word_index [Integer] Word index
        # @param dword_offset [Integer] Double-word offset (0-1)
        # @return [Integer]
        def read_int32(word_index, dword_offset = 0)
          value = read_data_field(word_index, dword_offset * 32, 32)
          # Convert to signed
          value >= 2147483648 ? value - 4294967296 : value
        end

        # Read an unsigned 32-bit integer
        # @param word_index [Integer] Word index
        # @param dword_offset [Integer] Double-word offset (0-1)
        # @return [Integer]
        def read_uint32(word_index, dword_offset = 0)
          read_data_field(word_index, dword_offset * 32, 32)
        end

        # Read a 64-bit integer
        # @param word_index [Integer] Word index
        # @return [Integer]
        def read_int64(word_index)
          value = read_data_field(word_index, 0, 64)
          # Convert to signed
          value >= 9223372036854775808 ? value - 18446744073709551616 : value
        end

        # Read an unsigned 64-bit integer
        # @param word_index [Integer] Word index
        # @return [Integer]
        def read_uint64(word_index)
          read_data_field(word_index, 0, 64)
        end

        # Read a 32-bit float
        # @param word_index [Integer] Word index
        # @param dword_offset [Integer] Double-word offset (0-1)
        # @return [Float]
        def read_float32(word_index, dword_offset = 0)
          bits = read_uint32(word_index, dword_offset)
          [bits].pack("L").unpack1("f")
        end

        # Read a 64-bit float
        # @param word_index [Integer] Word index
        # @return [Float]
        def read_float64(word_index)
          bits = read_uint64(word_index)
          [bits].pack("Q").unpack1("d")
        end

        # Read a boolean
        # @param word_index [Integer] Word index
        # @param bit_offset [Integer] Bit offset within word
        # @return [Boolean]
        def read_bool(word_index, bit_offset = 0)
          read_data_field(word_index, bit_offset, 1) == 1
        end

        # Read a pointer from pointer section
        # @param pointer_index [Integer] Pointer index in pointer section
        # @return [Hash, nil] Decoded pointer or nil
        def read_pointer(pointer_index)
          return nil if pointer_index >= @pointer_words

          pointer_word_offset = @word_offset + @data_words + pointer_index
          pointer_word = @segment_reader.read_word(@segment_id,
                                                   pointer_word_offset)

          return nil if pointer_word.zero?

          PointerDecoder.decode(pointer_word)
        end

        # Follow a pointer to get the target location
        # @param pointer_index [Integer] Pointer index
        # @return [Hash, nil] Target location info or nil
        def follow_pointer(pointer_index)
          pointer = read_pointer(pointer_index)
          return nil unless pointer
          return nil if pointer[:type] == :null

          case pointer[:type]
          when :struct
            # Struct pointer points relative to its own position
            pointer_position = @word_offset + @data_words + pointer_index
            target_offset = pointer_position + 1 + pointer[:offset]
            {
              type: :struct,
              segment_id: @segment_id,
              word_offset: target_offset,
              data_words: pointer[:data_words],
              pointer_words: pointer[:pointer_words],
            }
          when :list
            # List pointer points relative to its own position
            pointer_position = @word_offset + @data_words + pointer_index
            target_offset = pointer_position + 1 + pointer[:offset]
            {
              type: :list,
              segment_id: @segment_id,
              word_offset: target_offset,
              element_size: pointer[:element_size],
              element_count: pointer[:element_count],
            }
          when :far
            # Far pointer points to another segment
            {
              type: :far,
              segment_id: pointer[:segment_id],
              word_offset: pointer[:offset],
            }
          end
        end
      end
    end
  end
end
