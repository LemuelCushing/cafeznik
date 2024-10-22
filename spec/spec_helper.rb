require "webmock/rspec"
require_relative "../lib/cafeznik/cli"
require "vcr"
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = false # Sawyer::Resource is a dynamic object, so we can't verify partial doubles
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  # config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  # config.warnings = true
  # config.formatter = "documentation"
  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
  config.include_context "cli", type: :cli
end

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!

  config.filter_sensitive_data("<GITHUB_TOKEN>") { ENV["GITHUB_TOKEN"] }
end

WebMock.disable_net_connect!(allow_localhost: true)
