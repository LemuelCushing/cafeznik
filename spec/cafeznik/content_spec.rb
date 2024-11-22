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
    context "with default options" do
      it "copies content with headers to the clipboard" do
        content.copy_to_clipboard

        expected_output = <<~CONTENT.chomp
          ==> file1.txt <==
          Content of file1

          ==> file2.txt <==
          Content of file2
        CONTENT

        expect(Clipboard).to have_received(:copy).with(expected_output)
      end
    end

    context "without headers" do
      let(:include_headers) { false }

      it "copies content without headers" do
        content.copy_to_clipboard

        expected_output = <<~CONTENT.chomp
          Content of file1

          Content of file2
        CONTENT

        expect(Clipboard).to have_received(:copy).with(expected_output)
      end
    end

    context "including tree" do
      let(:include_tree) { true }

      it "includes the file tree in the content" do
        content.copy_to_clipboard

        expected_output = <<~CONTENT.chomp
          ==> Tree <==
          file1.txt
          file2.txt

          ==> file1.txt <==
          Content of file1

          ==> file2.txt <==
          Content of file2
        CONTENT

        expect(Clipboard).to have_received(:copy).with(expected_output)
      end
    end

    context "when a file returns nil content" do
      before do
        allow(source).to receive(:content).with("file2.txt").and_return(nil)
      end

      it "inclues files with nil content in the output" do
        content.copy_to_clipboard

        expected_output = <<~CONTENT.chomp
          ==> file1.txt <==
          Content of file1

          ==> file2.txt <==

        CONTENT

        expect(Clipboard).to have_received(:copy).with(expected_output)
      end

      # unless specifically set to skip them
      it "excludes files with nil content from the tree if skip_nil_content is set", skip: "TODO: implement" do
        content.copy_to_clipboard(skip_nil_content: true)

        expected_output = <<~CONTENT.chomp
          ==> file1.txt <==
          Content of file1
        CONTENT

        expect(Clipboard).to have_received(:copy).with(expected_output)
      end
    end

    context "when no files are provided" do
      let(:file_paths) { [] }

      it "copies an empty string to the clipboard" do
        content.copy_to_clipboard

        expect(Clipboard).to have_received(:copy).with("")
      end
    end

    context "when content exceeds maximum allowed lines" do
      before do
        stub_const("#{described_class}::MAX_LINES", 5)
        allow($stdin).to receive(:gets).and_return("y\n")
      end

      it "prompts the user for confirmation and proceeds when accepted" do
        content.copy_to_clipboard

        expect(Clipboard).to have_received(:copy)
      end

      context "and the user declines" do
        before do
          allow($stdin).to receive(:gets).and_return("n\n")
        end

        it "exits without copying to the clipboard" do
          expect(Clipboard).not_to have_received(:copy)
        end
      end
    end

    context "when source.content raises an error" do
      before do
        allow(source).to receive(:content).with("file1.txt").and_return("Content of file1")
        allow(source).to receive(:content).with("file2.txt").and_raise(StandardError, "Unexpected error")
        allow(Cafeznik::Log).to receive(:error)
      end

      it "logs the error and excludes the problematic file" do
        content.copy_to_clipboard

        expected_output = <<~CONTENT.chomp
          ==> file1.txt <==
          Content of file1
        CONTENT

        expect(Clipboard).to have_received(:copy).with(expected_output)
        expect(Cafeznik::Log).to have_received(:error).with("Error fetching content for file2.txt: Unexpected error")
      end
    end
  end
end
