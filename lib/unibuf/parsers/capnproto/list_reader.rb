# frozen_string_literal: true

require_relative "segment_reader"
require_relative "pointer_decoder"
require_relative "struct_reader"

module Unibuf
  module Parsers
    module Capnproto
      # Reader for Cap'n Proto list data
      # Lists can contain primitives, pointers, or structs
      class ListReader
        attr_reader :segment_reader, :segment_id, :word_offset, :element_size,
                    :element_count

        # Initialize list reader
        # @param segment_reader [SegmentReader] Segment reader
        # @param segment_id [Integer] Segment containing the list
        # @param word_offset [Integer] Word offset of list start
        # @param element_size [Integer] Element size code
        # @param element_count [Integer] Number of elements
        def initialize(segment_reader, segment_id, word_offset, element_size,
element_count)
          @segment_reader = segment_reader
          @segment_id = segment_id
          @word_offset = word_offset
          @element_size = element_size
          @element_count = element_count
        end

        # Get list length
        # @return [Integer]
        def length
          @element_count
        end
        alias size length

        # Read an element as a primitive value
        # @param index [Integer] Element index
        # @return [Object] Element value
        def read_primitive(index, type = :uint64)
          raise ArgumentError, "Index out of bounds" if index >= @element_count

          case @element_size
          when PointerDecoder::ELEMENT_SIZE_VOID
            nil
          when PointerDecoder::ELEMENT_SIZE_BIT
            read_bit(index)
          when PointerDecoder::ELEMENT_SIZE_BYTE
            read_byte(index, type)
          when PointerDecoder::ELEMENT_SIZE_TWO_BYTES
            read_two_bytes(index, type)
          when PointerDecoder::ELEMENT_SIZE_FOUR_BYTES
            read_four_bytes(index, type)
          when PointerDecoder::ELEMENT_SIZE_EIGHT_BYTES
            read_eight_bytes(index, type)
          else
            raise "Cannot read primitive from this list type"
          end
        end

        # Read an element as a pointer
        # @param index [Integer] Element index
        # @return [Hash, nil] Decoded pointer
        def read_pointer(index)
          raise ArgumentError, "Index out of bounds" if index >= @element_count
          raise "List elements are not pointers" unless @element_size == PointerDecoder::ELEMENT_SIZE_POINTER

          pointer_word = @segment_reader.read_word(@segment_id,
                                                   @word_offset + index)
          return nil if pointer_word.zero?

          PointerDecoder.decode(pointer_word)
        end

        # Read an element as a struct
        # @param index [Integer] Element index
        # @return [StructReader] Struct reader
        def read_struct(index)
          raise ArgumentError, "Index out of bounds" if index >= @element_count

          if @element_size == PointerDecoder::ELEMENT_SIZE_INLINE_COMPOSITE
            read_inline_composite_struct(index)
          else
            raise "List elements are not structs"
          end
        end

        # Read text (UTF-8 string)
        # @return [String]
        def read_text
          raise "Not a text list" unless @element_size == PointerDecoder::ELEMENT_SIZE_BYTE

          # Text is a byte list with null terminator
          bytes = (0...@element_count).map { |i| read_byte(i, :uint8) }
          # Remove null terminator
          bytes.pop if bytes.last.zero?
          bytes.pack("C*").force_encoding("UTF-8")
        end

        # Read data (binary blob)
        # @return [String]
        def read_data
          raise "Not a data list" unless @element_size == PointerDecoder::ELEMENT_SIZE_BYTE

          bytes = (0...@element_count).map { |i| read_byte(i, :uint8) }
          bytes.pack("C*")
        end

        private

        def read_bit(index)
          word_index = index / 64
          bit_index = index % 64
          word = @segment_reader.read_word(@segment_id,
                                           @word_offset + word_index)
          (word >> bit_index).allbits?(1)
        end

        def read_byte(index, type)
          word_index = index / 8
          byte_index = index % 8
          word = @segment_reader.read_word(@segment_id,
                                           @word_offset + word_index)

          value = (word >> (byte_index * 8)) & 0xFF

          # Convert to signed if  needed
          if type == :int8
            value >= 128 ? value - 256 : value
          else
            value
          end
        end

        def read_two_bytes(index, type)
          word_index = index / 4
          half_word_index = index % 4
          word = @segment_reader.read_word(@segment_id,
                                           @word_offset + word_index)

          value = (word >> (half_word_index * 16)) & 0xFFFF

          # Convert to signed if needed
          if type == :int16
            value >= 32768 ? value - 65536 : value
          else
            value
          end
        end

        def read_four_bytes(index, type)
          word_index = index / 2
          dword_index = index % 2
          word = @segment_reader.read_word(@segment_id,
                                           @word_offset + word_index)

          value = (word >> (dword_index * 32)) & 0xFFFFFFFF

          case type
          when :int32
            value >= 2147483648 ? value - 4294967296 : value
          when :float32
            [value].pack("L").unpack1("f")
          else
            value
          end
        end

        def read_eight_bytes(index, type)
          word = @segment_reader.read_word(@segment_id, @word_offset + index)

          case type
          when :int64
            word >= 9223372036854775808 ? word - 18446744073709551616 : word
          when :float64
            [word].pack("Q").unpack1("d")
          else
            word
          end
        end

        def read_inline_composite_struct(index)
          # For inline composite, first word is a tag describing struct size
          tag_word = @segment_reader.read_word(@segment_id, @word_offset)
          tag = PointerDecoder.decode(tag_word)

          raise "Invalid inline composite tag" unless tag[:type] == :struct

          data_words = tag[:data_words]
          pointer_words = tag[:pointer_words]
          struct_size = data_words + pointer_words

          # Structs start after the tag
          struct_offset = @word_offset + 1 + (index * struct_size)

          StructReader.new(
            @segment_reader,
            @segment_id,
            struct_offset,
            data_words,
            pointer_words,
          )
        end
      end
    end
  end
end
