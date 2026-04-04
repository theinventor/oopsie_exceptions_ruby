# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "oopsie_exceptions"
  spec.version       = OopsieExceptions::VERSION
  spec.authors       = ["Troy"]
  spec.summary       = "Lightweight exception capture and webhook delivery for Rails"
  spec.description   = "Captures unhandled exceptions from web requests and background jobs, enriches them with request/user/server context, and delivers structured JSON payloads to configurable webhook endpoints."
  spec.homepage      = "https://github.com/theinventor/oopsie_exceptions"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "railties", ">= 7.0"
  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "actionpack", ">= 7.0"
end
