# spec/cafeznik/source/github_spec.rb
# rubocop:disable RSpec/VerifiedDoubles
# Disabling this cop because Octokit::Client depends on Sawyer::Resource, a dynamic object.
# Its runtime-defined methods cannot be verified by RSpec, so we use non-verifying doubles.

require "spec_helper"
require "base64"

GitHubEntry = Struct.new(:path, :type)

RSpec.describe Cafeznik::Source::GitHub do
  let(:mock_client) { instance_double(Octokit::Client) }
  let(:repo) { "owner/repo" }
  let(:source) { described_class.new(repo: repo) }

  # Helper: convert an array of hashes into an array of GitHubEntry structs.
  def struct_tree(array)
    array.map { |hash| GitHubEntry.new(hash[:path], hash[:type]) }
  end

  before do
    allow(Octokit::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:repository).with(repo).and_return(double(default_branch: "main"))
    allow(mock_client).to receive(:tree).with(repo, "main", recursive: true)
                                        .and_return(double(tree: struct_tree(mock_github_tree)))
    allow(Cafeznik::Log).to receive_messages(error: nil, warn: nil, info: nil)
  end

  RSpec.shared_examples "handles error gracefully" do |method_name, args, error_class, log_method, log_fragment, exit_expected: false, expected_result: nil|
    before do
      allow(mock_client).to receive(method_name).and_raise(error_class.new({ message: "Mocked error" }))
      allow(Cafeznik::Log).to receive(log_method)
      allow(Kernel).to receive(:exit) if exit_expected
    end

    if exit_expected
      it "raises SystemExit" do
        expect { source.send(*args) }.to raise_error(SystemExit)
      end

      it "logs a fatal error message" do
        begin
          source.send(*args)
        rescue SystemExit
          # allow the test to proceed
        end
        expect(Cafeznik::Log).to have_received(log_method).with(include(log_fragment))
      end
    else
      it "returns #{expected_result.inspect}" do
        expect(source.send(*args)).to eq(expected_result)
      end

      it "logs an error message" do
        source.send(*args)
        expect(Cafeznik::Log).to have_received(log_method).with(include(log_fragment))
      end
    end
  end

  shared_examples "handles API errors gracefully" do |method, args|
    before do
      allow(mock_client).to receive(method).and_raise(
        Octokit::Error.new({ message: "Mocked API failure" })
      )
      allow(Cafeznik::Log).to receive(:error)
    end

    it "logs the correct error message" do
      source.send(*args)
      expect(Cafeznik::Log).to have_received(:error).with(include("Error fetching"))
    end

    it "returns nil when an API error occurs" do
      expect(source.send(*args)).to be_nil
    end
  end

  shared_examples "handles offline gracefully" do |_method, args, _result|
    before do
      allow(mock_client).to receive(:repository).and_raise(
        Faraday::ConnectionFailed.new("Failed to connect")
      )
      allow(Kernel).to receive(:exit).and_raise(SystemExit)
      allow(Cafeznik::Log).to receive(:fatal).and_call_original
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
      expect(Cafeznik::Log).to have_received(:fatal)
        .with(include("You might be offline, or something is keeping you from connecting"))
    end
  end

  describe "#initialize" do
    context "when offline" do
      before do
        allow(mock_client).to receive(:repository).and_raise(Faraday::ConnectionFailed, "Failed to connect")
        allow(Cafeznik::Log).to receive(:fatal).and_call_original
        allow(Kernel).to receive(:exit).and_raise(SystemExit)
      end

      it "logs a fatal error and exits", :aggregate_failures do
        expect { described_class.new(repo: repo) }.to raise_error(SystemExit)
        expect(Cafeznik::Log).to have_received(:fatal)
          .with(include("You might be offline"))
      end
    end

    context "when unauthorized" do
      before do
        allow(mock_client).to receive(:repository).and_raise(Octokit::Unauthorized.new({ message: "Unauthorized" }))
        allow(Cafeznik::Log).to receive(:fatal).and_call_original
        allow(Kernel).to receive(:exit).and_raise(SystemExit)
      end

      it "logs a fatal error and exits", :aggregate_failures do
        expect { described_class.new(repo: repo) }.to raise_error(SystemExit)
        expect(Cafeznik::Log).to have_received(:fatal)
          .with(include("Unable to connect to GitHub"))
      end
    end

    context "when repo is not found" do
      before do
        allow(mock_client).to receive(:repository).and_raise(Octokit::NotFound.new({ message: "Repo not found" }))
        allow(Cafeznik::Log).to receive(:fatal).and_call_original
        allow(Kernel).to receive(:exit).and_raise(SystemExit)
      end

      it "logs a fatal error and exits", :aggregate_failures do
        expect { described_class.new(repo: repo) }.to raise_error(SystemExit)
        expect(Cafeznik::Log).to have_received(:fatal)
          .with(include("Repo not found"))
      end
    end
  end

  describe "#access_token" do
    let(:tty_command) { instance_double(TTY::Command) }

    before do
      allow(TTY::Command).to receive(:new).and_return(tty_command)
      allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return(env_token)
    end

    context "when a token is set in ENV" do
      let(:env_token) { "env_token" }

      before { allow(tty_command).to receive(:run) }

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
        allow(tty_command).to receive(:run)
          .and_return(instance_double(TTY::Command::Result, out: "gh_token\n"))
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
        allow(tty_command).to receive(:run)
          .and_raise(TTY::Command::ExitError.new("gh auth token failed", result_double))
      end

      it "logs an error and exits" do
        expect { source.send(:access_token) }.to raise_error(SystemExit)
      end
    end
  end

  describe "#normalize_repo_name" do
    let(:repo_inputs) do
      proc do |repo|
        [
          "https://github.com/#{repo}",
          "github.com/#{repo}",
          "/#{repo}",
          "#{repo}/",
          repo
        ]
      end
    end

    let(:repo) { "owner/repo" }

    it "normalizes all inputs to the standard format" do
      repo_inputs.call(repo).each do |input|
        source.instance_variable_set(:@repo, input)
        source.send(:normalize_repo_name)
        expect(source.instance_variable_get(:@repo)).to eq(repo)
      end
    end
  end

  describe "#tree" do
    it "returns a sorted list of files and directories" do
      expected_tree = mock_github_tree.map { |entry| entry[:type] == "tree" ? "#{entry[:path]}/" : entry[:path] }.sort
      expect(source.tree).to eq(["./"] + expected_tree)
    end

    it_behaves_like "handles API errors gracefully", :tree, [:tree]
  end

  describe "#all_files" do
    before do
      allow(source).to receive(:tree).and_return(
        mock_github_tree.map do |entry|
          entry[:type] == "tree" ? "#{entry[:path]}/" : entry[:path]
        end
      )
    end

    it "returns only non-directory files" do
      expected_files = mock_github_tree.select { |entry| entry[:type] != "tree" }
                                       .map { |entry| entry[:path] }
      expect(source.all_files).to eq(expected_files)
    end
  end

  describe "#expand_dir" do
    before do
      allow(source).to receive(:tree).and_return(
        mock_github_tree.map do |entry|
          entry[:type] == "tree" ? "#{entry[:path]}/" : entry[:path]
        end
      )
    end

    it "returns all files in a directory" do
      # For example, expanding the "src/" directory should return all files under it that are not directories.
      expected = mock_github_tree.select { |entry| entry[:path].start_with?("src/") && entry[:type] != "tree" }
                                 .map { |entry| entry[:path] }
      expect(source.expand_dir("src/")).to eq(expected)
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

    it_behaves_like "handles API errors gracefully", :contents, [:content, "README.md"]
  end
end
# rubocop:enable RSpec/VerifiedDoubles
