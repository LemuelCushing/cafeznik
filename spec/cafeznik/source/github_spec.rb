require "spec_helper"

RSpec.describe Cafeznik::Source::GitHub do
  subject(:source) { described_class.new(repo: "owner/repo") }

  let(:mock_client) { Cafeznik::Testing::Doubles::GitHub.mock_client }

  before do
    allow(Octokit::Client).to receive(:new).and_return(mock_client)
  end

  it_behaves_like "a source"

  describe "#tree" do
    it "returns all files and directories from GitHub" do
      tree = source.tree

      expect(tree).to include("./")
      expect(tree).to include("README.md")
      expect(tree).to include("src/main.rb")
    end

    it "handles API errors gracefully" do
      allow(mock_client).to receive(:tree).and_raise(Octokit::Error)
      expect { source.tree }.not_to raise_error
      expect(source.tree).to be_nil
    end
  end

  describe "#content" do
    it "decodes base64 content from GitHub" do
      expect(source.content("README.md")).to eq("Test content")
    end

    it "handles missing files gracefully" do
      allow(mock_client).to receive(:contents).and_raise(Octokit::NotFound)
      expect(source.content("not_found.txt")).to be_nil
    end
  end
end
