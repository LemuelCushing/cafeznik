require "spec_helper"

RSpec.describe Cafeznik::Selector do
  subject(:selector) { described_class.new(source) }

  let(:source) { instance_double(Cafeznik::Source::Local) }
  let(:command) { instance_double(TTY::Command) }
  let(:result) { instance_double(TTY::Command::Result, out: selection_output.join("\n")) }
  let(:selection_output) { [] }
  let(:source_tree) { ["./", "file1.txt", "dir/"] }

  before do
    allow(TTY::Command).to receive(:new).and_return(command)
    allow(source).to receive_messages(
      tree: source_tree,
      dir?: false,
      expand_dir: ["dir/file1.txt", "dir/file2.txt"],
      all_files: ["file1.txt"]
    )
  end

  shared_context "with normal fzf execution" do
    before do
      allow(command).to receive(:run)
        .with("fzf --multi", any_args)
        .and_return(result)
    end
  end

  describe "#select" do
    context "when files are explicitly selected" do
      include_context "with normal fzf execution"
      let(:selection_output) { ["file1.txt"] }

      it "returns the expected file list" do
        expect(selector.select).to eq(["file1.txt"])
      end
    end

    context "when the root directory is selected" do
      include_context "with normal fzf execution"
      let(:selection_output) { ["./"] }

      it "returns all files" do
        expect(selector.select).to eq(["file1.txt"])
      end
    end

    context "when a directory is selected" do
      include_context "with normal fzf execution"
      let(:selection_output) { ["dir/"] }

      before { allow(source).to receive(:dir?).with("dir/").and_return(true) }

      it "expands the directory into its files" do
        expect(selector.select).to eq(["dir/file1.txt", "dir/file2.txt"])
      end
    end

    context "when no files are selected" do
      include_context "with normal fzf execution"

      it "returns an empty array" do
        expect(selector.select).to eq([])
      end
    end

    context "when the selected files exceed the maximum limit" do
      include_context "with normal fzf execution"
      let(:selection_output) { Array.new(25) { |i| "file#{i}.txt" } }

      before { allow($stdin).to receive(:gets).and_return("n\n") }

      it "exits when declined" do
        expect { selector.select }.to raise_error(SystemExit)
      end
    end

    context "when fzf is not installed" do
      before do
        allow(Cafeznik::Log).to receive(:error)
        allow(command).to receive(:run)
          .with("fzf --multi", any_args)
          .and_raise(Errno::ENOENT.new("No such file or directory - fzf"))
      end

      it "logs installation error" do
        expect(Cafeznik::Log).to receive(:error)
          .with("fzf is not installed. Please install it and try again.")
          .ordered
        expect { selector.select }.to raise_error(SystemExit)
      end
    end

    context "when an error occurs while running fzf" do
      before do
        error_result = instance_double(TTY::Command::Result,
                                       out: "",
                                       err: "unknown option: --fake-flag",
                                       exit_status: 2)
        error = TTY::Command::ExitError.new(
          "Running `fzf --multi --fake-flag` failed with\n  " \
          "exit status: 2\n  stdout: Nothing written\n  stderr: unknown option: --fake-flag",
          error_result
        )
        allow(Cafeznik::Log).to receive(:error)
        allow(command).to receive(:run).and_raise(error)
      end

      it "logs execution error" do
        expect { selector.send(:select_paths_with_fzf) }.to raise_error(SystemExit)
        expect(Cafeznik::Log).to have_received(:error).with(a_string_including("exit status: 2"))
      end
    end

    context "when the user exits fzf with esc" do
      before do
        error_result = instance_double(TTY::Command::Result,
                                       out: "", err: "", exit_status: 130)
        error = TTY::Command::ExitError.new(
          "Running `fzf --multi` failed with\n  " \
          "exit status: 130\n  stdout: Nothing written\n  stderr: Nothing written",
          error_result
        )
        allow(Cafeznik::Log).to receive(:info)
        allow(command).to receive(:run).and_raise(error)
      end

      it "logs cancellation" do
        expect { selector.select }.to raise_error(SystemExit)
        expect(Cafeznik::Log).to have_received(:info)
          .with("No files selected. Exiting..")
      end
    end
  end
end
