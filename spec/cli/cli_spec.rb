require "spec_helper"
require_relative "../../lib/cafeznik"

RSpec.describe Cafeznik::CLI, type: :cli do
  include_context "cli"

  let(:described_class) { Cafeznik::CLI }
  let(:repo) { "owner/repo" }
  let(:main_repo) { "main" }
  let(:logger_output) { StringIO.new }

  # Mock tree items to simulate GitHub's response structure
  let(:tree_items) do
    [
      double("Sawyer::Resource", type: "blob", path: "file1.txt"),
      double("Sawyer::Resource", type: "blob", path: "file2.txt"),
      double("Sawyer::Resource", type: "tree", path: "dir")
    ]
  end

  before do
    # Set up GitHub client mock
    mock_octokit = double("Octokit::Client")
    allow(Octokit::Client).to receive(:new).and_return(mock_octokit)
    allow(mock_octokit).to receive(:repository).with(repo).and_return(double("Sawyer::Resource", default_branch: "main"))
    allow(mock_octokit).to receive(:tree).with(repo, "main", recursive: true).and_return(double("Sawyer::Resource", tree: tree_items))
    allow(mock_octokit).to receive(:contents).with(repo, path: anything).and_return({ content: Base64.encode64("File content") })

    # Set up TTY command mock
    mock_tty = double("TTY::Command")
    allow(TTY::Command).to receive(:new).and_return(mock_tty)
    allow(mock_tty).to receive(:run) do |*args|
      if args[0].include?("fzf")
        double("Result", out: "file1.txt")
      else
        double("Result", out: args[0])
      end
    end

    # Set up local filesystem mock for tree test
    allow(Dir).to receive(:glob).with("**/*").and_return(["file1.txt", "dir/", "dir/file2.txt"])
    allow(File).to receive(:directory?) do |path|
      path.end_with?("/")
    end

    # Allow file reading but return mock content
    allow(File).to receive(:read).with(anything).and_return("Mock file content")

    allow(Clipboard).to receive(:copy).and_return(true)

    # Set up logger
    logger = Logger.new(logger_output)
    allow(Cafeznik::Log).to receive(:logger).and_return(logger)
  end

  shared_examples "a CLI command" do |args, expected_message|
    it "logs the expected message" do
      described_class.start(args)
      expect(logger_output.string).to include(expected_message)
    end
  end

  describe "Help Command" do
    it "outputs the expected help message to stdout" do
      expect { described_class.start(["--help"]) }.to output(/Commands:/).to_stdout
    end
  end

  describe "GitHub Mode Identification" do
    context "when --repo is provided" do
      it "identifies as GitHub mode" do
        described_class.start(["default", "--repo", repo])
        expect(logger_output.string).to include("GitHub mode")
      end
    end

    context "when --repo is not provided" do
      it "identifies as local mode" do
        described_class.start(["default"])
        expect(logger_output.string).to include("local mode")
      end
    end
  end

  describe "Options" do
    context "with --no-header" do
      it "excludes headers in the file content" do
        described_class.start(["default", "--no-header"])
        expect(logger_output.string).not_to include("==> file1.txt <==")
      end
    end

    context "with --with-tree" do
      it "includes the file tree in the content" do
        described_class.start(["default", "-t"])
        expect(Clipboard).to have_received(:copy).with(a_string_including("==> Tree <=="))
      end
    end

    context "with --verbose" do
      it "runs in verbose mode" do
        described_class.start(["default", "--verbose"])
        expect(logger_output.string).to include("DEBUG")
      end
    end
  end
end
