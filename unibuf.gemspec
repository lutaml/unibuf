# frozen_string_literal: true

require_relative "lib/unibuf/version"

Gem::Specification.new do |spec|
  spec.name = "unibuf"
  spec.version = Unibuf::VERSION
  spec.authors = ["Ronald Tse"]
  spec.email = ["ronald.tse@ribose.com"]

  spec.summary = "Universal Protocol Buffer & FlatBuffer Parser"
  spec.description = "A pure Ruby gem for parsing Protocol Buffers text format (textproto/txtpb) and FlatBuffers schema definitions with rich domain models"
  spec.homepage = "https://github.com/lutaml/unibuf"
  spec.required_ruby_version = ">= 3.1.0"
  spec.license = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/lutaml/unibuf"
  spec.metadata["changelog_uri"] = "https://github.com/lutaml/unibuf/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__,
                                             err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor
                          Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "bindata", "~> 2.5"
  spec.add_dependency "lutaml-model", "~> 0.7"
  spec.add_dependency "parslet", "~> 2.0"
  spec.add_dependency "thor", "~> 1.4"
end
