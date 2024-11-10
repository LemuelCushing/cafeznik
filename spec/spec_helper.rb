require "webmock/rspec"
require_relative "../lib/cafeznik"

Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f } # TODO: remove this if not needed

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = false # Sawyer::Resource is a dynamic object, so we can't verify partial doubles. I think.
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.order = :random

  # Add default metadata for spec directories TODO: remove this if not needed
  # config.define_derived_metadata(file_path: %r{/spec/cli/}) { |metadata| metadata[:type] ||= :cli }
  # config.define_derived_metadata(file_path: %r{/spec/sources/}) { |metadata| metadata[:type] ||= :source }
end
