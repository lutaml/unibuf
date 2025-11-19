# frozen_string_literal: true

module Unibuf
  module Parsers
    module Capnproto
      # Decoder for Cap'n Proto pointer words
      # Pointers are 64-bit words that encode type, offset, and size information
      class PointerDecoder
        # Pointer type constants (bits 0-1)
        POINTER_TYPE_STRUCT = 0
        POINTER_TYPE_LIST = 1
        POINTER_TYPE_FAR = 2
        POINTER_TYPE_OTHER = 3

        # List element size constants (bits 32-34 for list pointers)
        ELEMENT_SIZE_VOID = 0
        ELEMENT_SIZE_BIT = 1
        ELEMENT_SIZE_BYTE = 2
        ELEMENT_SIZE_TWO_BYTES = 3
        ELEMENT_SIZE_FOUR_BYTES = 4
        ELEMENT_SIZE_EIGHT_BYTES = 5
        ELEMENT_SIZE_POINTER = 6
        ELEMENT_SIZE_INLINE_COMPOSITE = 7

        # Decode a pointer word
        # @param word [Integer] 64-bit pointer word
        # @return [Hash] Decoded pointer information
        def self.decode(word)
          return null_pointer if word.zero?

          pointer_type = word & 0x3

          case pointer_type
          when POINTER_TYPE_STRUCT
            decode_struct_pointer(word)
          when POINTER_TYPE_LIST
            decode_list_pointer(word)
          when POINTER_TYPE_FAR
            decode_far_pointer(word)
          when POINTER_TYPE_OTHER
            decode_other_pointer(word)
          end
        end

        # Check if pointer is null
        # @param word [Integer] 64-bit pointer word
        # @return [Boolean]
        def self.null_pointer?(word)
          word.zero?
        end

        private_class_method def self.null_pointer
          {
            type: :null,
            null: true,
          }
        end

        # Decode struct pointer
        # Bits:
        # 0-1: Type = 0 (struct)
        # 2-31: Signed offset in words (30 bits)
        # 32-47: Data section size in words (16 bits)
        # 48-63: Pointer section size in words (16 bits)
        private_class_method def self.decode_struct_pointer(word)
          # Extract offset (bits 2-31, signed)
          offset_raw = (word >> 2) & 0x3FFFFFFF
          # Convert to signed 30-bit integer
          offset = offset_raw >= 0x20000000 ? offset_raw - 0x40000000 : offset_raw

          # Extract data section size (bits 32-47)
          data_size = (word >> 32) & 0xFFFF

          # Extract pointer section size (bits 48-63)
          pointer_size = (word >> 48) & 0xFFFF

          {
            type: :struct,
            offset: offset,
            data_words: data_size,
            pointer_words: pointer_size,
          }
        end

        # Decode list pointer
        # Bits:
        # 0-1: Type = 1 (list)
        # 2-31: Signed offset in words (30 bits)
        # 32-34: Element size (3 bits)
        # 35-63: Element count (29 bits)
        private_class_method def self.decode_list_pointer(word)
          # Extract offset (bits 2-31, signed)
          offset_raw = (word >> 2) & 0x3FFFFFFF
          offset = offset_raw >= 0x20000000 ? offset_raw - 0x40000000 : offset_raw

          # Extract element size (bits 32-34)
          element_size = (word >> 32) & 0x7

          # Extract element count (bits 35-63)
          element_count = (word >> 35) & 0x1FFFFFFF

          {
            type: :list,
            offset: offset,
            element_size: element_size,
            element_count: element_count,
            element_size_name: element_size_name(element_size),
          }
        end

        # Decode far pointer
        # Bits:
        # 0-1: Type = 2 (far)
        # 2: Landing pad flag (0 = normal, 1 = double-far)
        # 3-31: Offset in words within target segment (29 bits)
        # 32-63: Target segment ID (32 bits)
        private_class_method def self.decode_far_pointer(word)
          # Extract landing pad flag (bit 2)
          double_far = (word >> 2).allbits?(0x1)

          # Extract offset (bits 3-31)
          offset = (word >> 3) & 0x1FFFFFFF

          # Extract segment ID (bits 32-63)
          segment_id = (word >> 32) & 0xFFFFFFFF

          {
            type: :far,
            offset: offset,
            segment_id: segment_id,
            double_far: double_far,
          }
        end

        # Decode other pointer (capability)
        private_class_method def self.decode_other_pointer(word)
          # Extract capability index (bits 32-63)
          capability_index = (word >> 32) & 0xFFFFFFFF

          {
            type: :capability,
            index: capability_index,
          }
        end

        # Get element size name
        private_class_method def self.element_size_name(size)
          case size
          when ELEMENT_SIZE_VOID then :void
          when ELEMENT_SIZE_BIT then :bit
          when ELEMENT_SIZE_BYTE then :byte
          when ELEMENT_SIZE_TWO_BYTES then :two_bytes
          when ELEMENT_SIZE_FOUR_BYTES then :four_bytes
          when ELEMENT_SIZE_EIGHT_BYTES then :eight_bytes
          when ELEMENT_SIZE_POINTER then :pointer
          when ELEMENT_SIZE_INLINE_COMPOSITE then :inline_composite
          else :unknown
          end
        end
      end
    end
  end
end
