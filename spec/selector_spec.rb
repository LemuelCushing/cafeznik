require "spec_helper"

RSpec.describe Cafeznik::Selector do
  subject(:selector) { described_class.new(source) }

  let(:source) { instance_double(Cafeznik::Source::Local) }
  let(:mock_command) { instance_double(TTY::Command) }
  let(:mock_result) { double(out: "file1.txt\n") }

  before do
    allow(TTY::Command).to receive(:new).and_return(mock_command)
    allow(mock_command).to receive(:run).and_return(mock_result)
    allow(source).to receive(:tree).and_return(["./", "file1.txt", "dir/"])
    allow(source).to receive(:all_files).and_return(["file1.txt"])
    allow(source).to receive(:expand_dir)
    allow(source).to receive(:dir?).with("file1.txt").and_return(false)
  end

  describe "#select" do
    it "returns selected files" do
      expect(selector.select).to eq(["file1.txt"])
    end

    context "when root directory is selected" do
      let(:mock_result) { double(out: "./\n") }

      it "returns all files" do
        expect(selector.select).to eq(["file1.txt"])
      end
    end
  end
end
