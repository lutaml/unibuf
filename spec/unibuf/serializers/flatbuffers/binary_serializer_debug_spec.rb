# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "unibuf/serializers/flatbuffers/binary_serializer"
require "unibuf/parsers/flatbuffers/binary_parser"
require "unibuf/models/flatbuffers/schema"
require "unibuf/models/flatbuffers/table_definition"
require "unibuf/models/flatbuffers/field_definition"

RSpec.describe "FlatBuffers Serialization Debug" do
  let(:simple_schema) do
    table_def = Unibuf::Models::Flatbuffers::TableDefinition.new(
      name: "Monster",
      fields: [
        Unibuf::Models::Flatbuffers::FieldDefinition.new(
          name: "hp",
          type: "int",
        ),
        Unibuf::Models::Flatbuffers::FieldDefinition.new(
          name: "name",
          type: "string",
        ),
      ],
    )

    Unibuf::Models::Flatbuffers::Schema.new(
      root_type: "Monster",
      tables: [table_def],
    )
  end

  it "debugs binary format" do
    data = { "hp" => 100, "name" => "Orc" }

    serializer = Unibuf::Serializers::Flatbuffers::BinarySerializer.new(simple_schema)

    puts "\n=== Input Data ==="
    puts data.inspect
    puts "Schema fields: #{simple_schema.find_table('Monster').fields.map(&:name).inspect}"

    binary_data = serializer.serialize(data)

    puts "\n=== Binary Output ==="
    puts "Total size: #{binary_data.bytesize} bytes"
    puts "Hex: #{binary_data.bytes.map { |b| format('%02x', b) }.join(' ')}"
    puts "Bytes: #{binary_data.bytes.inspect}"

    puts "\n=== Parsing Attempt ==="
    parser = Unibuf::Parsers::Flatbuffers::BinaryParser.new(simple_schema)

    begin
      result = parser.parse(binary_data)
      puts "Parse successful: #{result.inspect}"
    rescue StandardError => e
      puts "Parse failed: #{e.class} - #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end

    # Try manual inspection
    puts "\n=== Manual Inspection ==="
    io = StringIO.new(binary_data)
    io.set_encoding(Encoding::BINARY)

    # Read root offset
    root_offset = io.read(4).unpack1("L<")
    puts "Root offset at 0: #{root_offset}"

    if root_offset < binary_data.bytesize
      # Read vtable offset at root
      io.seek(root_offset)
      vtable_offset = io.read(4)&.unpack1("l<")
      puts "VTable offset at #{root_offset}: #{vtable_offset}"

      if vtable_offset
        vtable_pos = root_offset - vtable_offset
        puts "VTable position: #{vtable_pos}"

        if vtable_pos >= 0 && vtable_pos < binary_data.bytesize
          io.seek(vtable_pos)
          vtable_size = io.read(2)&.unpack1("S<")
          object_size = io.read(2)&.unpack1("S<")
          puts "VTable size: #{vtable_size}, Object size: #{object_size}"

          # Read field offsets
          num_fields = (vtable_size - 4) / 2
          puts "Number of field entries: #{num_fields}"
          num_fields.times do |i|
            field_offset = io.read(2)&.unpack1("S<")
            puts "  Field #{i} offset: #{field_offset}"
          end
        end
      end
    end
  end
end
