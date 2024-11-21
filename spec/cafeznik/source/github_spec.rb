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
    allow(mock_client).to receive(:repository).with(repo)
    allow(Cafeznik::Log).to receive_messages(error: nil, warn: nil, info: nil)
  end

  shared_examples "handles API errors gracefully" do |method, args, result|
    before do
      allow(mock_client).to receive(method).and_raise(Octokit::Error)
    end

    it "does not raise errors" do
      expect { source.send(*args) }.not_to raise_error
    end

    it "returns #{result.inspect}" do
      expect(source.send(*args)).to eq(result)
    end
  end

  shared_examples "handles offline gracefully" do |_method, args, _result|
    before do
      allow(mock_client).to receive(:repository).and_raise(Faraday::ConnectionFailed, "Failed to connect")
    end

    it "raises SystemExit when offline" do
      expect { source.send(*args) }.to raise_error(SystemExit)
    end

    it "logs an error message when offline" do
      begin
        source.send(*args)
      rescue SystemExit
        # Allow the test to proceed
      end
      expect(Cafeznik::Log).to have_received(:error).with("Unable to connect to GitHub. Please check your internet connection.")
    end
  end

  describe "#tree" do
    let(:mock_tree) do
      [
        double(path: "README.md", type: "blob"),
        double(path: "src", type: "tree"),
        double(path: "src/main.rb", type: "blob")
      ]
    end

    before do
      allow(mock_client).to receive(:repository).with(repo).and_return(double(default_branch: "main"))
      allow(mock_client).to receive(:tree).with(repo, "main", recursive: true).and_return(double(tree: mock_tree))
    end

    it "returns a sorted list of files and directories" do
      expect(source.tree).to eq(["./", "README.md", "src/", "src/main.rb"])
    end

    it_behaves_like "handles API errors gracefully", :tree, [:tree], nil
    it_behaves_like "handles offline gracefully", :tree, [:tree], nil
  end

  describe "#all_files" do
    let(:mock_tree) do
      [
        double(path: "README.md", type: "blob"),
        double(path: "src", type: "tree"),
        double(path: "src/main.rb", type: "blob")
      ]
    end

    before do
      allow(source).to receive(:tree).and_return(["./", "README.md", "src/", "src/main.rb"])
    end

    it "returns only non-directory files" do
      expect(source.all_files).to eq(["README.md", "src/main.rb"])
    end
  end

  describe "#expand_dir" do
    before do
      allow(source).to receive(:tree).and_return(["./", "README.md", "src/", "src/main.rb"])
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

  describe "#content" do
    let(:encoded_content) { Base64.encode64("Sample Content") }

    before do
      allow(mock_client).to receive(:contents).with(repo, path: "README.md")
                                              .and_return(content: encoded_content)
    end

    it "decodes and returns the file content" do
      expect(source.content("README.md")).to eq("Sample Content")
    end

    it_behaves_like "handles API errors gracefully", :contents, [:content, "README.md"], nil
    it_behaves_like "handles offline gracefully", :contents, [:content, "README.md"], nil
  end

  describe "#access_token" do
    let(:tty_command) { instance_double(TTY::Command) }

    before do
      allow(TTY::Command).to receive(:new).and_return(tty_command)
      allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return(env_token)
    end

    context "when a token is set in ENV" do
      let(:env_token) { "env_token" }

      before do
        allow(tty_command).to receive(:run)
      end

      it "returns the token from ENV" do
        expect(source.send(:access_token)).to eq("env_token")
      end

      it "does not fetch the token via gh CLI" do
        source.send(:access_token)
        expect(tty_command).not_to have_received(:run)
      end
    end

    context "when token is available via gh CLI" do
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
