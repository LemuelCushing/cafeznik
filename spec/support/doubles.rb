require "rspec/mocks"

module Cafeznik
  module Testing
    module Doubles
      module GitHub
        extend RSpec::Mocks::ExampleMethods

        module_function

        def mock_client
          double("Octokit::Client").tap do |client|
            allow(client).to receive(:repository).and_return(mock_repository)
            allow(client).to receive(:tree).and_return(mock_tree)
            allow(client).to receive(:contents).and_return(mock_content)
          end
        end

        def mock_repository
          double("Repository", default_branch: "main")
        end

        def mock_tree
          double("Tree", tree: [
                   double("TreeEntry", type: "blob", path: "README.md"),
                   double("TreeEntry", type: "blob", path: "src/main.rb"),
                   double("TreeEntry", type: "blob", path: "src/lib/helper.rb"),
                   double("TreeEntry", type: "tree", path: "src"),
                   double("TreeEntry", type: "tree", path: "src/lib")
                 ])
        end

        def mock_content
          { content: Base64.encode64("Test content") }
        end
      end
    end
  end
end
