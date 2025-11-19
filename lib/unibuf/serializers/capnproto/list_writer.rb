# frozen_string_literal: true

require_relative "segment_builder"
require_relative "pointer_encoder"

module Unibuf
  module Serializers
    module Capnproto
      # Writer for Cap'n Proto list data
      # Handles lists of primitives, pointers, and structs
      class ListWriter
        attr_reader :segment_builder, :segment_id, :word_offset, :element_size,
                    :element_count

        # Initialize list writer
        # @param segment_builder [SegmentBuilder] Segment builder
        # @param segment_id [Integer] Segment ID
        # @param word_offset [Integer] Word offset in segment
        # @param element_size [Integer] Element size code
        # @param element_count [Integer] Number of elements
        def initialize(segment_builder, segment_id, word_offset, element_size,
element_count)
          @segment_builder = segment_builder
          @segment_id = segment_id
          @word_offset = word_offset
          @element_size = element_size
          @element_count = element_count
        end

        # Write a primitive element
        # @param index [Integer] Element index
        # @param value [Object] Element value
        # @param type [Symbol] Value type
        def write_primitive(index, value, type = :uint64)
          raise ArgumentError, "Index out of bounds" if index >= @element_count

          case @element_size
          when PointerEncoder::ELEMENT_SIZE_VOID
            # Void - nothing to write
          when PointerEncoder::ELEMENT_SIZE_BIT
            write_bit(index, value)
          when PointerEncoder::ELEMENT_SIZE_BYTE
            write_byte(index, value, type)
          when PointerEncoder::ELEMENT_SIZE_TWO_BYTES
            write_two_bytes(index, value, type)
          when PointerEncoder::ELEMENT_SIZE_FOUR_BYTES
            write_four_bytes(index, value, type)
          when PointerEncoder::ELEMENT_SIZE_EIGHT_BYTES
            write_eight_bytes(index, value, type)
          else
            raise "Cannot write primitive to this list type"
          end
        end

        # Write a pointer element
        # @param index [Integer] Element index
        # @param pointer_word [Integer] Encoded pointer word
        def write_pointer(index, pointer_word)
          raise ArgumentError, "Index out of bounds" if index >= @element_count
          raise "List elements are not pointers" unless @element_size == PointerEncoder::ELEMENT_SIZE_POINTER

          @segment_builder.write_word(@segment_id, @word_offset + index,
                                      pointer_word)
        end

        # Write text (UTF-8 string) as byte list
        # @param text [String] Text to write
        def write_text(text)
          raise "Not a byte list" unless @element_size == PointerEncoder::ELEMENT_SIZE_BYTE

          bytes = text.bytes + [0] # Add null terminator
          bytes.each_with_index do |byte, i|
            write_byte(i, byte, :uint8) if i < @element_count
          end
        end

        # Write data (binary) as byte list
        # @param data [String] Binary data to write
        def write_data(data)
          raise "Not a byte list" unless @element_size == PointerEncoder::ELEMENT_SIZE_BYTE

          data.bytes.each_with_index do |byte, i|
            write_byte(i, byte, :uint8) if i < @element_count
          end
        end

        private

        def write_bit(index, value)
          word_index = index / 64
          bit_index = index % 64

          all_segments = @segment_builder.segments
          current = if @segment_id < all_segments.length
                      all_segments[@segment_id][@word_offset + word_index] || 0
                    else
                      0
                    end

          new_value = if value
                        current | (1 << bit_index)
                      else
                        current & ~(1 << bit_index)
                      end

          @segment_builder.write_word(@segment_id, @word_offset + word_index,
                                      new_value)
        end

        def write_byte(index, value, type)
          word_index = index / 8
          byte_index = index % 8

          all_segments = @segment_builder.segments
          current = if @segment_id < all_segments.length
                      all_segments[@segment_id][@word_offset + word_index] || 0
                    else
                      0
                    end

          # Clear the byte
          mask = 0xFF << (byte_index * 8)
          cleared = current & ~mask

          # Set new value
          byte_value = type == :int8 && value.negative? ? value + 256 : value
          new_value = cleared | ((byte_value & 0xFF) << (byte_index * 8))

          @segment_builder.write_word(@segment_id, @word_offset + word_index,
                                      new_value)
        end

        def write_two_bytes(index, value, type)
          word_index = index / 4
          half_word_index = index % 4

          all_segments = @segment_builder.segments
          current = if @segment_id < all_segments.length
                      all_segments[@segment_id][@word_offset + word_index] || 0
                    else
                      0
                    end

          # Clear the half-word
          mask = 0xFFFF << (half_word_index * 16)
          cleared = current & ~mask

          # Set new value
          short_value = type == :int16 && value.negative? ? value + 65536 : value
          new_value = cleared | ((short_value & 0xFFFF) << (half_word_index * 16))

          @segment_builder.write_word(@segment_id, @word_offset + word_index,
                                      new_value)
        end

        def write_four_bytes(index, value, type)
          word_index = index / 2
          dword_index = index % 2

          all_segments = @segment_builder.segments
          current = if @segment_id < all_segments.length
                      all_segments[@segment_id][@word_offset + word_index] || 0
                    else
                      0
                    end

          # Clear the dword
          mask = 0xFFFFFFFF << (dword_index * 32)
          cleared = current & ~mask

          # Set new value
          int_value = if type == :float32
                        [value].pack("f").unpack1("L")
                      else
                        type == :int32 && value.negative? ? value + 4294967296 : value
                      end

          new_value = cleared | ((int_value & 0xFFFFFFFF) << (dword_index * 32))

          @segment_builder.write_word(@segment_id, @word_offset + word_index,
                                      new_value)
        end

        def write_eight_bytes(index, value, type)
          word_value = if type == :float64
                         [value].pack("d").unpack1("Q")
                       elsif type == :int64 && value.negative?
                         value + 18446744073709551616
                       else
                         value
                       end

          @segment_builder.write_word(@segment_id, @word_offset + index,
                                      word_value & 0xFFFFFFFFFFFFFFFF)
        end
      end
    end
  end
end
