require "spec_helper"

RSpec.describe Cafeznik::Selector do
  subject(:selector) { described_class.new(source) }

  let(:source) { instance_double(Cafeznik::Source::Local) }
  let(:command) { instance_double(TTY::Command) }
  let(:result) { instance_double(TTY::Command::Result, out: selection_output.join("\n")) }
  let(:source_tree) { ["./", "file1.txt", "dir/", "dir/file1.txt", "dir/file2.txt"] }
  let(:selection_output) { [] }

  before do
    allow(TTY::Command).to receive(:new).and_return(command)
    # Allow any version of the command with any arguments
    allow(command).to receive(:run).and_return(result)
    allow(Cafeznik::ToolChecker).to receive(:fzf_available?).and_return(true)

    allow(source).to receive_messages(
      tree: source_tree,
      dir?: false,
      expand_dir: ["dir/file1.txt", "dir/file2.txt"],
      all_files: ["file1.txt", "dir/file1.txt", "dir/file2.txt"]
    )
  end

  describe "#select" do
    context "when files are explicitly selected" do
      let(:selection_output) { ["file1.txt"] }

      it "returns the selected files" do
        expect(selector.select).to eq(["file1.txt"])
      end
    end

    context "when the root directory is selected" do
      let(:selection_output) { ["./"] }

      it "returns all files in the source tree" do
        expect(selector.select).to eq(["file1.txt", "dir/file1.txt", "dir/file2.txt"])
      end
    end

    context "when a directory is selected" do
      let(:selection_output) { ["dir/"] }

      before { allow(source).to receive(:dir?).with("dir/").and_return(true) }

      it "expands the directory and returns its files" do
        expect(selector.select).to eq(["dir/file1.txt", "dir/file2.txt"])
      end
    end

    context "when no files are selected" do
      it "returns an empty array" do
        expect(selector.select).to eq([])
      end
    end

    context "when selected files exceed the limit" do
      let(:selection_output) { Array.new(25) { |i| "file#{i}.txt" } }

      before { allow($stdin).to receive(:gets).and_return("n\n") }

      it "raises a SystemExit error" do
        expect { selector.select }.to raise_error(SystemExit)
      end
    end
  end

  describe "fzf errors" do
    context "when fzf is not installed" do
      before do
        allow(Cafeznik::ToolChecker).to receive(:fzf_available?).and_return(false)
        allow(Cafeznik::Log).to receive(:fatal)
      end

      it "logs a missing installation error" do
        selector.select
        expect(Cafeznik::Log).to have_received(:fatal)
      end
    end

    context "when fzf execution error occurs" do
      before do
        allow(Cafeznik::Log).to receive(:error)
        error = TTY::Command::ExitError.new(
          "Error running fzf",
          instance_double(TTY::Command::Result, exit_status: 2, err: "unknown option: --fake-flag", out: "")
        )
        allow(command).to receive(:run).and_raise(error)
      end

      it "logs the fzf error message and exits" do
        expect { selector.select }.to raise_error(SystemExit)
      end
    end

    context "when user cancels fzf" do
      before do
        allow(Cafeznik::Log).to receive(:info)
        error = TTY::Command::ExitError.new(
          "User exited fzf",
          instance_double(TTY::Command::Result, exit_status: 130, err: "", out: "")
        )
        allow(command).to receive(:run).and_raise(error)
      end

      it "logs the cancellation message and exits" do
        expect { selector.select }.to raise_error(SystemExit)
      end
    end
  end
end
