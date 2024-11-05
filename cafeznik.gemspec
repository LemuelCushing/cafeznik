# cafeznik.gemspec
Gem::Specification.new do |spec|
  spec.name          = "cafeznik"
  spec.version       = "0.4.0"
  spec.authors       = ["Lem"]
  spec.summary       = "A CLI tool for managing files and directories"
  spec.description   = "CLI tool for handling files and directories locally and remotely."
  spec.homepage      = "https://github.com/LemuelCushing/cafeznik"
  spec.license       = "MIT"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.required_ruby_version = ">= 3.3"

  spec.files         = Dir["lib/**/*.rb", "bin/cafeznik", "README.md"]
  spec.bindir        = "bin"
  spec.executables   = ["cafeznik"]

  spec.add_dependency "base64", "~> 0.2"
  spec.add_dependency "clipboard", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "octokit", "~> 9.2"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "tty-command", "~> 0.10"

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.66"
  spec.add_development_dependency "rubocop-performance", "~> 1.22"
  spec.add_development_dependency "rubocop-rspec", "~> 3.2"
  spec.add_development_dependency "standard", "~> 1.41"
  spec.add_development_dependency "webmock", "~> 3.24"
end
