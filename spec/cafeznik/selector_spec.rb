require "spec_helper"

RSpec.describe Cafeznik::Selector do
  subject(:selector) { described_class.new(source) }

  let(:source) { instance_double(Cafeznik::Source::Local) }
  let(:mock_command) { instance_double(TTY::Command) }
  let(:selection_output) { [] }

  let(:mock_result) { instance_double(TTY::Command::Result, out: selection_output.join("\n")) }
  let(:source_tree) { ["./", "file1.txt", "dir/"] }

  before do
    allow(TTY::Command).to receive(:new).and_return(mock_command)
    allow(mock_command).to receive(:run).and_return(mock_result)
    allow(source).to receive_messages(
      tree: source_tree,
      dir?: false,
      expand_dir: ["dir/file1.txt", "dir/file2.txt"],
      all_files: ["file1.txt"]
    )
  end

  describe "#select" do
    context "when files are explicitly selected" do
      let(:selection_output) { ["file1.txt"] }

      it "returns the expected file list" do
        expect(selector.select).to eq(["file1.txt"])
      end
    end

    context "when the root directory is selected" do
      let(:selection_output) { ["./"] }

      it "returns all files" do
        expect(selector.select).to eq(["file1.txt"])
      end
    end

    context "when a directory is selected" do
      let(:selection_output) { ["dir/"] }

      before { allow(source).to receive(:dir?).with("dir/").and_return(true) }

      it "expands the directory into its files" do
        expect(selector.select).to eq(["dir/file1.txt", "dir/file2.txt"])
      end
    end

    context "when no files are selected" do
      let(:selection_output) { [] }

      it "returns an empty array" do
        expect(selector.select).to eq([])
      end
    end

    context "when the selected files exceed the maximum limit" do
      let(:selection_output) { Array.new(25) { |i| "file#{i}.txt" } }

      before do
        allow($stdin).to receive(:gets).and_return("n\n")
      end

      it "prompts for confirmation and exits if declined" do
        expect { selector.select }.to raise_error(SystemExit)
      end
    end

    context "when an error occurs while running fzf" do
      before do
        result = instance_double(
          TTY::Command::Result,
          out: "",
          err: "fzf failed",
          exit_status: 1
        )
        error = TTY::Command::ExitError.new("fzf failed", result)
        allow(mock_command).to receive(:run).and_raise(error)
        allow(Cafeznik::Log).to receive(:info)
      end

      it "logs the error" do
        expect(Cafeznik::Log).to have_received(:info).with(/No files selected, exiting/)
      end

      it "exits gracefully" do
        expect { selector.select }.to raise_error(SystemExit)
      end
    end
  end
end
