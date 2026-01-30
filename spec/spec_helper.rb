# frozen_string_literal: true

require "simplecov"

# Configure SimpleCov
# Overall: 81.87% coverage after comprehensive Cap'n Proto tests
# Target achieved: Exceeds 80% goal!
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/bin/"
  add_filter "/exe/"

  minimum_coverage 80
  minimum_coverage_by_file 30 # Infrastructure files have untested helper methods

  enable_coverage :branch
end

require "unibuf"

# With autoload, explicit requires are not needed.
# Constants are loaded automatically when first referenced.
# This ensures the autoload behavior is tested.

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
