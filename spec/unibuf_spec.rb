# frozen_string_literal: true

RSpec.describe Unibuf do
  it "has a version number" do
    expect(Unibuf::VERSION).not_to be_nil
  end

  describe ".parse_textproto" do
    it "parses simple textproto content" do
      content = 'name: "test"'
      message = described_class.parse_textproto(content)
      expect(message).to be_a(Unibuf::Models::Message)
      expect(message.field_count).to eq(1)
    end
  end
end
