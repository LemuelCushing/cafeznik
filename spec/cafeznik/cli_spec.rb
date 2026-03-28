require "spec_helper"
require_relative "../../lib/cafeznik"

RSpec.describe Cafeznik::CLI do
  subject(:cli) { described_class.start(args) }

  let(:args) { ["default"] }
  let(:mock_selector) { instance_double(Cafeznik::Selector, select: ["file1.txt"]) }
  let(:mock_content) { instance_double(Cafeznik::Content) }
  let(:logger_output) { StringIO.new }

  before do
    allow(Cafeznik::Selector).to receive(:new).and_return(mock_selector)
    allow(Cafeznik::Content).to receive(:new).and_return(mock_content)
    allow(mock_content).to receive(:copy_to_clipboard)

    allow(Cafeznik::Log).to receive(:verbose=)
    allow(Cafeznik::Log).to receive(:info) do |msg|
      logger_output.puts(msg)
    end

    stub_request(:get, %r{https://api\.github\.com/repos/.*})
      .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })
  end

  describe "default command" do
    it "initiates file selection and copies content to clipboard", :aggregate_failures do
      described_class.start(args)
      expect(mock_selector).to have_received(:select)
      expect(mock_content).to have_received(:copy_to_clipboard)
    end
  end

  context "when run with --repo option" do
    let(:args) { ["default", "--repo", "owner/repo"] }

    it "runs in GitHub mode" do
      described_class.start(args)
      expect(logger_output.string).to include("Running in GitHub mode")
    end

    it "initializes GitHub source for the specified repository" do
      described_class.start(args)
      expect(Cafeznik::Content).to have_received(:new).with(hash_including(source: instance_of(Cafeznik::Source::GitHub)))
    end
  end

  describe "option handling" do
    it "excludes headers if --no-header is provided" do
      described_class.start(["default", "--no-header"])
      expect(Cafeznik::Content).to have_received(:new).with(hash_including(include_headers: false))
    end

    it "includes the file tree if --with-tree is provided" do
      described_class.start(["default", "--with-tree"])
      expect(Cafeznik::Content).to have_received(:new).with(hash_including(include_tree: true))
    end

    it "enables verbose logging with --verbose option" do
      described_class.start(["default", "--verbose"])
      expect(Cafeznik::Log).to have_received(:verbose=).with(true)
    end
  end

  describe "logging behavior" do
    it "logs start and completion messages" do
      described_class.start(args)
      expect(logger_output.string).to include("Running in local mode")
    end
  end

  describe "error handling" do
    it "handles invalid repository format" do
      expect do
        described_class.start(["default", "--repo", "invalid-format"])
      end.to raise_error(Octokit::InvalidRepository, /invalid as a repository/)
    end

    it "handles invalid command line arguments" do
      expect do
        described_class.start(["default", "--invalid-flag"])
      end.to raise_error(SystemExit)
    end
  end

  describe "diff subcommand" do
    let(:args) { ["diff"] }

    before do
      allow(Open3).to receive(:capture2).with("git", "merge-base", "HEAD", "main").and_return(["master_sha", double(success?: true)])
      allow(Open3).to receive(:capture2).with("git", "diff", "--name-status", "master_sha").and_return(["M\tfile1.rb\nA\tfile2.rb", double(success?: true)])
      allow(Open3).to receive(:capture2).with("git", "ls-files", "--others", "--exclude-standard").and_return(["file3.rb", double(success?: true)])
      allow(Open3).to receive(:capture2).with("git", "log", "-1", "--format=%ct", "--", "file1.rb").and_return(["1678886400", double(success?: true)])
      allow(Open3).to receive(:capture2).with("git", "log", "-1", "--format=%ct", "--", "file2.rb").and_return(["", double(success?: true)])
      allow(Open3).to receive(:capture2).with("git", "log", "-1", "--format=%ct", "--", "file3.rb").and_return(["", double(success?: true)])
      allow(File).to receive(:mtime).with("file1.rb").and_return(Time.at(1678886400))
      allow(File).to receive(:mtime).with("file2.rb").and_return(Time.at(1678886400))
      allow(File).to receive(:mtime).with("file3.rb").and_return(Time.at(1678886400))
      allow(Open3).to receive(:capture2).with("git", "diff", "--name-only", "--", "file1.rb").and_return(["file1.rb", double(success?: true)])
      allow(Open3).to receive(:capture2).with("git", "diff", "--name-only", "--", "file2.rb").and_return(["", double(success?: true)])
      allow(Open3).to receive(:capture2).with("git", "diff", "--name-only", "--", "file3.rb").and_return(["", double(success?: true)])
    end

    it "runs the diff command" do
      expect(Cafeznik::Selector).to receive(:new).and_return(mock_selector)
      expect(mock_selector).to receive(:select).and_return(["file1.rb"])
      expect(Cafeznik::Content).to receive(:new).and_return(mock_content)
      expect(mock_content).to receive(:copy_to_clipboard)
      described_class.start(args)
    end

    it "runs the diff command with --select" do
      expect(Cafeznik::Selector).to receive(:new).and_return(mock_selector)
      expect(mock_selector).to receive(:select).with(select: true, select_all: false).and_return(["file1.rb"])
      expect(Cafeznik::Content).to receive(:new).and_return(mock_content)
      expect(mock_content).to receive(:copy_to_clipboard)
      described_class.start(["diff", "--select"])
    end

    it "runs the diff command with --select-all" do
      expect(Cafeznik::Selector).to receive(:new).and_return(mock_selector)
      expect(mock_selector).to receive(:select).with(select: false, select_all: true).and_return(["file1.rb", "file2.rb", "file3.rb"])
      expect(Cafeznik::Content).to receive(:new).and_return(mock_content)
      expect(mock_content).to receive(:copy_to_clipboard)
      described_class.start(["diff", "--select-all"])
    end

    it "runs the diff command with --raw" do
      expect(Cafeznik::Selector).to receive(:new).and_return(mock_selector)
      expect(mock_selector).to receive(:select).and_return(["file1.rb"])
      expect(Cafeznik::Content).to receive(:new).and_return(mock_content)
      expect(mock_content).to receive(:copy_to_clipboard).with(output_file: nil, raw: true)
      described_class.start(["diff", "--raw"])
    end

    it "runs the diff command with --output" do
      expect(Cafeznik::Selector).to receive(:new).and_return(mock_selector)
      expect(mock_selector).to receive(:select).and_return(["file1.rb"])
      expect(Cafeznik::Content).to receive(:new).and_return(mock_content)
      expect(mock_content).to receive(:copy_to_clipboard).with(output_file: "output.txt", raw: false)
      described_class.start(["diff", "--output", "output.txt"])
    end

    it "runs the diff command with --repeat" do
      allow(File).to receive(:open).with("repeat.json", "r").and_yield("[\"file1.rb\"]")
      expect(Cafeznik::Selector).to receive(:new).and_return(mock_selector)
      expect(mock_selector).to receive(:select).and_return(["file1.rb"])
      expect(Cafeznik::Content).to receive(:new).and_return(mock_content)
      expect(mock_content).to receive(:copy_to_clipboard)
      described_class.start(["diff", "--repeat", "repeat.json"])
    end
  end
end
