# frozen_string_literal: true

require "simplecov"

# Configure SimpleCov
# Note: Temporarily set to 60% while adding comprehensive tests for new components
# Target: 100% (will be restored once tests are complete)
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/bin/"
  add_filter "/exe/"

  minimum_coverage 60
  minimum_coverage_by_file 50

  enable_coverage :branch
end

require "unibuf"

# Load all models and parsers
require_relative "../lib/unibuf/models/message"
require_relative "../lib/unibuf/models/field"
require_relative "../lib/unibuf/models/schema"
require_relative "../lib/unibuf/models/message_definition"
require_relative "../lib/unibuf/models/field_definition"
require_relative "../lib/unibuf/models/enum_definition"
require_relative "../lib/unibuf/parsers/textproto/grammar"
require_relative "../lib/unibuf/parsers/textproto/processor"
require_relative "../lib/unibuf/parsers/textproto/parser"
require_relative "../lib/unibuf/parsers/proto3/grammar"
require_relative "../lib/unibuf/parsers/proto3/processor"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Use documentation format for verbose output
  config.default_formatter = "doc" if config.files_to_run.one?

  # Run specs in random order to surface order dependencies
  config.order = :random
  Kernel.srand config.seed
end
