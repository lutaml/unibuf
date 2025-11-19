# frozen_string_literal: true

module Unibuf
  module Serializers
    module Capnproto
      # Encoder for Cap'n Proto pointer words
      # Encodes pointer information into 64-bit words
      class PointerEncoder
        # Pointer type constants (bits 0-1)
        POINTER_TYPE_STRUCT = 0
        POINTER_TYPE_LIST = 1
        POINTER_TYPE_FAR = 2
        POINTER_TYPE_OTHER = 3

        # List element size constants
        ELEMENT_SIZE_VOID = 0
        ELEMENT_SIZE_BIT = 1
        ELEMENT_SIZE_BYTE = 2
        ELEMENT_SIZE_TWO_BYTES = 3
        ELEMENT_SIZE_FOUR_BYTES = 4
        ELEMENT_SIZE_EIGHT_BYTES = 5
        ELEMENT_SIZE_POINTER = 6
        ELEMENT_SIZE_INLINE_COMPOSITE = 7

        class << self
          # Encode a null pointer
          # @return [Integer] 64-bit word
          def encode_null
            0
          end

          # Encode a struct pointer
          # @param offset [Integer] Signed word offset (relative to pointer position)
          # @param data_words [Integer] Number of data words
          # @param pointer_words [Integer] Number of pointer words
          # @return [Integer] 64-bit pointer word
          def encode_struct(offset, data_words, pointer_words)
            # Bits: [pointer_words:16][data_words:16][offset:30][type:2]

            # Convert signed offset to 30-bit representation
            offset_bits = offset & 0x3FFFFFFF

            word = POINTER_TYPE_STRUCT |
              (offset_bits << 2) |
              (data_words << 32) |
              (pointer_words << 48)

            word & 0xFFFFFFFFFFFFFFFF
          end

          # Encode a list pointer
          # @param offset [Integer] Signed word offset
          # @param element_size [Integer] Element size code (0-7)
          # @param element_count [Integer] Number of elements
          # @return [Integer] 64-bit pointer word
          def encode_list(offset, element_size, element_count)
            # Bits: [element_count:29][element_size:3][offset:30][type:2]

            # Convert signed offset to 30-bit representation
            offset_bits = offset & 0x3FFFFFFF

            word = POINTER_TYPE_LIST |
              (offset_bits << 2) |
              (element_size << 32) |
              (element_count << 35)

            word & 0xFFFFFFFFFFFFFFFF
          end

          # Encode a far pointer
          # @param segment_id [Integer] Target segment ID
          # @param offset [Integer] Word offset within target segment
          # @param double_far [Boolean] Landing pad flag
          # @return [Integer] 64-bit pointer word
          def encode_far(segment_id, offset, double_far: false)
            # Bits: [segment_id:32][offset:29][double_far:1][type:2]

            double_far_bit = double_far ? 1 : 0

            word = POINTER_TYPE_FAR |
              (double_far_bit << 2) |
              (offset << 3) |
              (segment_id << 32)

            word & 0xFFFFFFFFFFFFFFFF
          end

          # Encode a capability pointer
          # @param index [Integer] Capability index
          # @return [Integer] 64-bit pointer word
          def encode_capability(index)
            # Bits: [index:32][reserved:30][type:2]

            word = POINTER_TYPE_OTHER |
              (index << 32)

            word & 0xFFFFFFFFFFFFFFFF
          end

          # Get element size code for a type
          # @param type_name [String, Symbol] Type name
          # @return [Integer] Element size code
          def element_size_for_type(type_name)
            case type_name.to_s
            when "Void" then ELEMENT_SIZE_VOID
            when "Bool" then ELEMENT_SIZE_BIT
            when "Int8", "UInt8" then ELEMENT_SIZE_BYTE
            when "Int16", "UInt16" then ELEMENT_SIZE_TWO_BYTES
            when "Int32", "UInt32", "Float32" then ELEMENT_SIZE_FOUR_BYTES
            when "Int64", "UInt64", "Float64" then ELEMENT_SIZE_EIGHT_BYTES
            else ELEMENT_SIZE_POINTER # For user types and Text/Data
            end
          end
        end
      end
    end
  end
end
