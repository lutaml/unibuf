# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Google Fonts Round-Trip Integration" do
  let(:fixtures_dir) do
    File.expand_path("../../../fixtures/google_fonts", __dir__)
  end
  let(:parser) { Unibuf::Parsers::Textproto::Parser.new }

  describe "curated interesting fixtures" do
    # We've curated 7 interesting fixtures with diverse Protocol Buffer features:
    # - robotoflex: Multi-axis variable font (GRAD, XOPQ, XTRA, YOPQ, etc.)
    # - mavenpro: Static font example
    # - opensans: Multiple variants (roman, italic, condensed)
    # - playfair (3 variants): Has optical size (opsz) axis
    # - wavefont: Custom axes (ROND, YALN, wght)
    #
    # Previous 1,969 files archived to /tmp/unibuf-archived-fixtures for reference

    let(:fixture_files) do
      Dir.glob(File.join(fixtures_dir, "*.pb"))
    end

    it "has curated interesting fixtures" do
      expect(fixture_files.size).to eq(7)
    end

    it "includes key test cases" do
      basenames = fixture_files.map { |f| File.basename(f, "_METADATA.pb") }

      # Check for our interesting cases
      expect(basenames).to include("robotoflex") # Multi-axis
      expect(basenames).to include("mavenpro")   # Static
      expect(basenames).to include("opensans")   # Popular
      expect(basenames).to include("playfair")   # Optical size
      expect(basenames).to include("wavefont")   # Custom axes
    end
  end

  describe "sample fixtures" do
    it "parses robotoflex (multi-axis variable font)" do
      file_path = File.join(fixtures_dir, "robotoflex_METADATA.pb")
      skip "File not found" unless File.exist?(file_path)

      content = File.read(file_path)
      message = parser.parse(content)

      expect(message).to be_a(Unibuf::Models::Message)
      expect(message.field_count).to be > 0

      # Should have axes field for variable font
      expect(message.find_field("axes")).not_to be_nil
    end

    it "handles nested message blocks" do
      file_path = File.join(fixtures_dir, "opensans_METADATA.pb")
      skip "File not found" unless File.exist?(file_path)

      content = File.read(file_path)
      message = parser.parse(content)

      expect(message.nested?).to be true
      expect(message.find_field("fonts")).not_to be_nil
    end

    it "handles repeated fields" do
      file_path = File.join(fixtures_dir, "mavenpro_METADATA.pb")
      skip "File not found" unless File.exist?(file_path)

      content = File.read(file_path)
      message = parser.parse(content)

      # subsets appears multiple times
      subsets_fields = message.find_fields("subsets")
      expect(subsets_fields.size).to be > 1
    end
  end

  describe "round-trip testing" do
    # Test all curated fixtures
    context "curated fixtures" do
      fixture_files = Dir.glob(File.join(File.expand_path("../../../fixtures/google_fonts", __dir__),
                                         "*.pb"))

      fixture_files.each do |file_path|
        it "round-trips #{File.basename(file_path)}" do
          original_content = File.read(file_path)

          # Parse
          message = parser.parse(original_content)
          expect(message).to be_a(Unibuf::Models::Message)

          # Serialize back
          regenerated_content = message.to_textproto
          expect(regenerated_content).to be_a(String)

          # Parse again
          reparsed_message = parser.parse(regenerated_content)

          # Verify semantic equivalence
          expect(reparsed_message).to eq(message)
        end
      end
    end
  end
end
