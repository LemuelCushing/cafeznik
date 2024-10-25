require "spec_helper"

RSpec.describe Cafeznik::Source::GitHub do
  subject(:source) { described_class.new(repo) }

  it_behaves_like "a source"

  let(:repo) { "owner/repo" }
  let(:mock_client) { instance_double(Octokit::Client) }
  let(:mock_repo) { double(default_branch: "main") }
  let(:mock_tree) do
    double(tree: [
             double(type: "blob", path: "file1.txt"),
             double(type: "blob", path: "dir/file2.txt")
           ])
  end

  before do
    allow(Octokit::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:repository).with(repo).and_return(mock_repo)
    allow(mock_client).to receive(:tree)
      .with(repo, "main", recursive: true)
      .and_return(mock_tree)
    allow(mock_client).to receive(:contents)
      .and_return({ content: Base64.encode64("content") })
  end

  describe "#content" do
    it "decodes base64 content from GitHub" do
      expect(source.content("file1.txt")).to eq("content")
    end
  end
end
