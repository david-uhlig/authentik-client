# frozen_string_literal: true

require_relative "lib/authentik/client/version"

Gem::Specification.new do |spec|
  spec.name = "authentik-client"
  spec.version = Authentik::Client::VERSION
  spec.authors = ["David Uhlig"]
  spec.email = ["david.uhlig@gmail.com"]

  spec.summary = "A developer-friendly Ruby wrapper for the authentik API that simplifies managing authentik configuration objects."
  spec.description = <<~DESC
    A developer-friendly Ruby wrapper around the auto-generated authentik-api gem, offering an idiomatic interface for interacting with authentik configuration objects and abstracting away the complexity of the underlying OpenAPI client.
  DESC
  spec.homepage = "https://github.com/david-uhlig/authentik-client"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/david-uhlig/authentik-client"
  spec.metadata["changelog_uri"] = "https://github.com/david-uhlig/authentik-client/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .standard.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "authentik-api"
  spec.add_runtime_dependency "zeitwerk", "~> 2.6"

  spec.add_development_dependency "irb"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "railties"
  spec.add_development_dependency "rspec", "~> 3.2"
  spec.add_development_dependency "standard", "~> 1.3"
end
