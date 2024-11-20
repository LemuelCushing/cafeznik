# rubocop:disable RSpec/VerifiedDoubles
# Disabling this cop because Octokit::Client depends on Sawyer::Resource, a dynamic object.
# Its runtime-defined methods cannot be verified by RSpec, so we use non-verifying doubles.
require "spec_helper"
require "base64"

RSpec.describe Cafeznik::Source::GitHub do
  let(:mock_client) { instance_double(Octokit::Client) }
  let(:repo) { "owner/repo" }
  let(:source) { described_class.new(repo:) }

  before do
    allow(Octokit::Client).to receive(:new).and_return(mock_client)
  end

  describe "#tree" do
    context "when the tree is fetched successfully" do
      let(:mock_tree) do
        [
          double(path: "README.md", type: "blob"),
          double(path: "src", type: "tree")
        ]
      end

      before do
        allow(mock_client).to receive(:repository).with(repo).and_return(double(default_branch: "main"))
        allow(mock_client).to receive(:tree).with(repo, "main", recursive: true).and_return(double(tree: mock_tree))
      end

      it "returns a sorted list of files and directories" do
        expect(source.tree).to eq(["./", "README.md", "src/"])
      end
    end

    context "when the GitHub API raises an error" do
      before do
        allow(mock_client).to receive(:repository).with(repo).and_raise(Octokit::NotFound)
      end

      it "does not raise an error when GitHub API raises an error" do # TODO: move this to a shared example
        expect { source.tree }.not_to raise_error
      end

      it "returns nil when GitHub API raises an error" do # TODO: move this to a shared example
        expect(source.tree).to be_nil
      end
    end
  end

  describe "#content" do
    context "when file content is fetched successfully" do
      let(:encoded_content) { Base64.encode64("Sample Content") }

      before do
        allow(mock_client).to receive(:contents).with(repo, path: "README.md").and_return(content: encoded_content)
      end

      it "decodes and returns the file content" do
        expect(source.content("README.md")).to eq("Sample Content")
      end
    end

    context "when the GitHub API raises an error" do
      before do
        allow(mock_client).to receive(:contents).with(repo, path: "README.md").and_raise(Octokit::Forbidden)
      end

      it "does not raise an error when GitHub API raises an error" do # TODO: move this to a shared example
        expect { source.content("README.md") }.not_to raise_error
      end

      it "returns nil when GitHub API raises an error" do # TODO: move this to a shared example
        expect(source.content("README.md")).to be_nil
      end
    end
  end

  describe "#all_files" do
    let(:tree) { ["./", "src/", "README.md"] }

    before do
      allow(source).to receive(:tree).and_return(tree)
    end

    it "returns only non-directory files" do
      expect(source.all_files).to eq(["README.md"])
    end
  end

  describe "#expand_dir" do
    let(:tree) { ["./", "src/", "src/main.rb", "README.md"] }

    before do
      allow(source).to receive(:tree).and_return(tree)
    end

    it "returns all files in a directory" do
      expect(source.expand_dir("src/")).to eq(["src/main.rb"])
    end
  end

  describe "#dir?" do
    it "returns true for paths ending with a slash" do
      expect(source.dir?("src/")).to be(true)
    end

    it "returns false for paths not ending with a slash" do
      expect(source.dir?("README.md")).to be(false)
    end
  end

  describe "#tree with grep" do
    before do
      allow(mock_client).to receive(:search_code).and_return(
        double(items: [double(path: "README.md"), double(path: "src/main.rb")])
      )
    end

    it "returns only files matching the grep pattern" do
      source = described_class.new(repo:, grep: "main")
      expect(source.tree).to eq(["README.md", "src/main.rb"])
    end
  end

  describe "access token retrieval" do
    before do
      allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return(env_token)
      allow(TTY::Command).to receive(:new).and_return(tty_command)
    end

    let(:tty_command) { instance_double(TTY::Command) }

    context "when a token is set in ENV" do
      let(:env_token) { "env_token" }

      before do
        allow(tty_command).to receive(:run) # Stub run to enable spying
      end

      it "returns the token from ENV" do
        expect(source.send(:access_token)).to eq("env_token")
      end

      it "does not fetch the token via gh CLI" do
        source.send(:access_token)
        expect(tty_command).not_to have_received(:run)
      end
    end

    context "when no token is set in ENV but available via gh CLI" do
      let(:env_token) { nil }

      before do
        allow(tty_command).to receive(:run).and_return(
          instance_double(TTY::Command::Result, out: "gh_token\n")
        )
      end

      it "fetches the token via gh CLI" do
        expect(source.send(:access_token)).to eq("gh_token")
      end
    end

    context "when no token is available" do
      let(:env_token) { nil }

      before do
        result_double = instance_double(
          TTY::Command::Result,
          exit_status: 1,
          out: nil,
          err: "Error message"
        )
        allow(tty_command).to receive(:run).and_raise(
          TTY::Command::ExitError.new("gh auth token failed", result_double)
        )
      end

      it "logs an error and exits" do
        expect { source.send(:access_token) }.to raise_error(SystemExit)
      end
    end
  end
end

# rubocop:enable RSpec/VerifiedDoubles
