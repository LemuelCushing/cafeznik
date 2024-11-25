require "spec_helper"

RSpec.describe Cafeznik::Content do
  subject(:content) { described_class.new(**params) }

  let(:params) do
    {
      source:,
      file_paths:,
      include_headers:,
      include_tree:
    }
  end

  let(:source) { instance_double(Cafeznik::Source::Local) }
  let(:file_paths) { ["file1.txt", "file2.txt"] }
  let(:include_headers) { true }
  let(:include_tree) { false }

  before do
    allow(source).to receive(:content).with("file1.txt").and_return("Content of file1")
    allow(source).to receive(:content).with("file2.txt").and_return("Content of file2")
    allow(source).to receive(:tree).and_return(["./", "file1.txt", "file2.txt"])
    allow(Clipboard).to receive(:copy)
  end

  describe "#copy_to_clipboard" do
    context "when headers are included" do
      it "copies content with headers to the clipboard" do
        content.copy_to_clipboard

        expect(Clipboard).to have_received(:copy).with(expected_output_with_headers)
      end
    end

    context "when headers are excluded" do
      let(:include_headers) { false }

      it "copies content without headers" do
        content.copy_to_clipboard

        expect(Clipboard).to have_received(:copy).with(expected_output_without_headers)
      end
    end

    context "when including the tree" do
      let(:include_tree) { true }

      it "includes the file tree in the content" do
        content.copy_to_clipboard

        expect(Clipboard).to have_received(:copy).with(expected_output_with_tree)
      end
    end

    context "when a file has nil content" do
      before do
        allow(source).to receive(:content).with("file2.txt").and_return(nil)
      end

      it "includes files with nil content in the output" do
        content.copy_to_clipboard

        expect(Clipboard).to have_received(:copy).with(expected_output_with_nil_content)
      end

      it "excludes files with nil content when skip_nil_content is set", skip: "TODO: implement" do
        content.copy_to_clipboard(skip_nil_content: true)

        expect(Clipboard).to have_received(:copy).with(expected_output_without_nil_or_errored_content)
      end
    end

    context "when no files are provided" do
      let(:file_paths) { [] }

      it "copies an empty string to the clipboard" do
        content.copy_to_clipboard

        expect(Clipboard).to have_received(:copy).with("")
      end
    end

    context "when content exceeds the maximum allowed lines" do
      before { stub_const("#{described_class}::MAX_LINES", 5) }

      it "proceeds when the user confirms" do
        allow($stdin).to receive(:gets).and_return("y\n")

        content.copy_to_clipboard

        expect(Clipboard).to have_received(:copy)
      end

      it "exits without copying when the user declines" do
        allow($stdin).to receive(:gets).and_return("n\n")

        expect(Clipboard).not_to have_received(:copy)
      end
    end

    context "when source.content raises an error" do
      before do
        allow(source).to receive(:content).with("file1.txt").and_return("Content of file1")
        allow(source).to receive(:content).with("file2.txt").and_raise(StandardError, "Unexpected error")
        allow(Cafeznik::Log).to receive(:error)
      end

      it "logs the error" do
        content.copy_to_clipboard

        expect(Cafeznik::Log).to have_received(:error).with("Error fetching content for file2.txt: Unexpected error")
      end

      it "excludes the problematic file" do
        content.copy_to_clipboard

        expect(Clipboard).to have_received(:copy).with(expected_output_without_nil_or_errored_content)
      end
    end
  end

  def expected_output_with_headers = <<~CONTENT.chomp
    ==> file1.txt <==
    Content of file1

    ==> file2.txt <==
    Content of file2
  CONTENT

  def expected_output_without_headers = <<~CONTENT.chomp
    Content of file1

    Content of file2
  CONTENT

  def expected_output_with_tree = <<~CONTENT.chomp
    ==> Tree <==
    file1.txt
    file2.txt

    ==> file1.txt <==
    Content of file1

    ==> file2.txt <==
    Content of file2
  CONTENT

  def expected_output_with_nil_content = <<~CONTENT.chomp
    ==> file1.txt <==
    Content of file1

    ==> file2.txt <==

  CONTENT

  def expected_output_without_nil_or_errored_content = <<~CONTENT.chomp
    ==> file1.txt <==
    Content of file1
  CONTENT
end
