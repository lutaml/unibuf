# frozen_string_literal: true

module Unibuf
  module Models
    module Capnproto
      # Represents a Cap'n Proto schema (.capnp file)
      class Schema
        attr_reader :file_id, :usings, :structs, :enums, :interfaces,
                    :constants

        def initialize(attributes = {})
          @file_id = attributes[:file_id] || attributes["file_id"]
          @usings = Array(attributes[:usings] || attributes["usings"])
          @structs = Array(attributes[:structs] || attributes["structs"])
          @enums = Array(attributes[:enums] || attributes["enums"])
          @interfaces = Array(
            attributes[:interfaces] || attributes["interfaces"],
          )
          @constants = Array(
            attributes[:constants] || attributes["constants"],
          )
        end

        # Queries
        def find_struct(name)
          structs.find { |s| s.name == name }
        end

        def find_enum(name)
          enums.find { |e| e.name == name }
        end

        def find_interface(name)
          interfaces.find { |i| i.name == name }
        end

        def find_type(name)
          find_struct(name) || find_enum(name) || find_interface(name)
        end

        def struct_names
          structs.map(&:name)
        end

        def enum_names
          enums.map(&:name)
        end

        def interface_names
          interfaces.map(&:name)
        end

        # Validation
        def valid?
          validate!
          true
        rescue ValidationError
          false
        end

        def validate!
          raise ValidationError, "File ID required" unless file_id

          structs.each(&:validate!)
          enums.each(&:validate!)
          interfaces.each(&:validate!)

          true
        end

        def to_h
          {
            file_id: file_id,
            usings: usings,
            structs: structs.map(&:to_h),
            enums: enums.map(&:to_h),
            interfaces: interfaces.map(&:to_h),
            constants: constants,
          }
        end
      end
    end
  end
end
