# spec/cafeznik/source/github_spec.rb
# rubocop:disable RSpec/VerifiedDoubles
# Disabling this cop because Octokit::Client depends on Sawyer::Resource, a dynamic object.
# Its runtime-defined methods cannot be verified by RSpec, so we use non-verifying doubles.

require "spec_helper"
require "base64"

RSpec.describe Cafeznik::Source::GitHub do
  let(:mock_client) { instance_double(Octokit::Client) }
  let(:repo) { "owner/repo" }
  let(:source) { described_class.new(repo: repo) }

  let(:github_tree_entries) { create_github_tree_entries }
  let(:expected_tree_with_exclusions) { expected_github_tree }

  before do
    allow(Octokit::Client).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:repository).with(repo).and_return(double(default_branch: "main"))
    allow(mock_client).to receive(:tree).with(repo, "main", recursive: true)
                                        .and_return(double(tree: github_tree_entries))
    allow(Cafeznik::Log).to receive_messages(error: nil, warn: nil, info: nil, fatal: nil)
  end

  shared_examples "handles error conditions" do |options|
    let(:method_name) { options[:method] }
    let(:args) { options[:args] || [] }
    let(:error_class) { options[:error_class] }
    let(:error_message) { options[:error_message] || "Mocked error" }
    let(:log_level) { options[:log_level] || :error }
    let(:log_fragment) { options[:log_fragment] || "Error" }
    let(:exit_expected) { options[:exit_expected] || false }
    let(:expected_result) { options[:expected_result] }

    before do
      allow(mock_client).to receive(method_name).and_raise(
        error_class.new({ message: error_message })
      )

      allow(Kernel).to receive(:exit).and_raise(SystemExit) if exit_expected
    end

    it "handles the error appropriately" do
      if exit_expected
        expect { source.send(*args) }.to raise_error(SystemExit)
      else
        result = source.send(*args)
        expect(result).to eq(expected_result) if expected_result
      end
    end

    it "logs the appropriate message" do
      begin
        source.send(*args)
      rescue SystemExit
        # allow the test to proceed
      end

      expect(Cafeznik::Log).to have_received(log_level).with(include(log_fragment))
    end
  end

  describe "#initialize" do
    [
      {
        context: "when offline",
        error_class: Faraday::ConnectionFailed,
        error_message: "Failed to connect",
        log_level: :fatal,
        log_fragment: "You might be offline"
      },
      {
        context: "when unauthorized",
        error_class: Octokit::Unauthorized,
        error_message: "Unauthorized",
        log_level: :fatal,
        log_fragment: "Unable to connect to GitHub"
      },
      {
        context: "when repo is not found",
        error_class: Octokit::NotFound,
        error_message: "Repo not found",
        log_level: :fatal,
        log_fragment: "Repo not found"
      }
    ].each do |scenario|
      context scenario[:context] do
        before do
          allow(mock_client).to receive(:repository).and_raise(
            scenario[:error_class].new({ message: scenario[:error_message] })
          )
          # allow(Kernel).to receive(:exit).and_raise(SystemExit)
        end

        it "logs a fatal error" do
          described_class.new(repo:)
          expect(Cafeznik::Log).to have_received(scenario[:log_level]).with(include(scenario[:log_fragment]))
        end
      end
    end
  end

  describe "#access_token" do
    let(:tty_command) { instance_double(TTY::Command) }

    before do
      allow(TTY::Command).to receive(:new).and_return(tty_command)
    end

    context "when token sources are available" do
      # Table-driven approach for token sources
      [
        {
          source: "ENV",
          env_token: "env_token",
          gh_token: nil,
          expected_token: "env_token",
          should_run_gh: false
        },
        {
          source: "gh CLI",
          env_token: nil,
          gh_token: "gh_token",
          expected_token: "gh_token",
          should_run_gh: true
        }
      ].each do |scenario|
        context "from #{scenario[:source]}" do
          before do
            allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return(scenario[:env_token])

            if scenario[:gh_token]
              allow(tty_command).to receive(:run)
                .and_return(instance_double(TTY::Command::Result, out: "#{scenario[:gh_token]}\n"))
            else
              allow(tty_command).to receive(:run)
            end
          end

          it "returns the expected token" do
            expect(source.send(:access_token)).to eq(scenario[:expected_token])
          end

          it "#{scenario[:should_run_gh] ? 'fetches' : 'does not fetch'} the token via gh CLI" do
            source.send(:access_token)

            if scenario[:should_run_gh]
              expect(tty_command).to have_received(:run)
            else
              expect(tty_command).not_to have_received(:run)
            end
          end
        end
      end
    end

    context "when no token is available" do
      before do
        allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return(nil)
        result_double = instance_double(
          TTY::Command::Result,
          exit_status: 1,
          out: nil,
          err: "Error message"
        )
        allow(tty_command).to receive(:run)
          .and_raise(TTY::Command::ExitError.new("gh auth token failed", result_double))
        allow(Kernel).to receive(:exit).and_raise(SystemExit)
      end

      it "logs an error and exits" do
        expect { source.send(:access_token) }.to raise_error(SystemExit)
      end
    end
  end

  describe "#normalize_repo_name" do
    [
      "https://github.com/owner/repo",
      "github.com/owner/repo",
      "/owner/repo",
      "owner/repo/",
      "owner/repo"
    ].each do |repo_format|
      it "normalizes '#{repo_format}' to the standard format" do
        source.instance_variable_set(:@repo, repo_format)
        source.send(:normalize_repo_name)
        expect(source.instance_variable_get(:@repo)).to eq("owner/repo")
      end
    end
  end

  describe "#tree" do
    it "returns a sorted list of files and directories with binary files excluded" do
      expect(source.tree).to eq(expected_tree_with_exclusions)
    end

    it_behaves_like "handles error conditions", {
      method: :tree,
      args: [:tree],
      error_class: Octokit::Error,
      log_fragment: "Error fetching",
      expected_result: []
    }
  end

  describe "#all_files" do
    let(:non_dir_entries) { github_tree_entries.reject { |entry| entry.type == "tree" } }

    before do
      allow(source).to receive(:tree).and_return(format_github_tree(non_dir_entries))
    end

    it "returns only non-directory files, excluding the usual suspects" do
      expected_files = github_tree_entries
                       .reject { |entry| entry.type == "tree" }
                       .map(&:path)
      expect(source.all_files).to match_array(expected_files)
    end
  end

  describe "#expand_dir" do
    before do
      allow(source).to receive(:tree).and_return(format_github_tree(github_tree_entries))
    end

    it "returns all files in a directory" do
      expected = github_tree_entries
                 .select { |entry| entry.path.start_with?("src/") }
                 .reject { |entry| entry.type == "tree" }
                 .map(&:path)
      expect(source.expand_dir("src/")).to match_array(expected)
    end
  end

  describe "#dir?" do
    [
      { path: "src/", expected: true },
      { path: "README.md", expected: false }
    ].each do |scenario|
      it "returns #{scenario[:expected]} for '#{scenario[:path]}'" do
        expect(source.dir?(scenario[:path])).to be(scenario[:expected])
      end
    end
  end

  describe "#content" do
    let(:sample_content) { "Sample Content" }
    let(:encoded_content) { Base64.encode64(sample_content) }

    before do
      allow(mock_client).to receive(:contents).with(repo, path: "README.md")
                                              .and_return(content: encoded_content)
    end

    it "decodes and returns the file content" do
      expect(source.content("README.md")).to eq(sample_content)
    end

    it_behaves_like "handles error conditions", {
      method: :contents,
      args: [:content, "README.md"],
      error_class: Octokit::Error,
      log_fragment: "Error fetching",
      expected_result: nil
    }
  end
end
# rubocop:enable RSpec/VerifiedDoubles
