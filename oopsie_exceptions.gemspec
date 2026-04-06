# frozen_string_literal: true

require_relative "lib/oopsie_exceptions/version"

Gem::Specification.new do |spec|
  spec.name          = "oopsie_exceptions"
  spec.version       = OopsieExceptions::VERSION
  spec.authors       = ["Troy"]
  spec.summary       = "Lightweight exception capture and webhook delivery for Ruby (framework-agnostic)"
  spec.description   = "Captures unhandled exceptions from web requests and background jobs, enriches them with request/user/server context, and delivers structured JSON payloads to configurable webhook endpoints. Works with any Rack-based framework; optional Rails integration included."
  spec.homepage      = "https://github.com/theinventor/oopsie_exceptions"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "source_code_uri" => "https://github.com/theinventor/oopsie_exceptions",
    "changelog_uri" => "https://github.com/theinventor/oopsie_exceptions/releases",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", ">= 2.0"
end
