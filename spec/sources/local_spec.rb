require "spec_helper"

RSpec.describe Cafeznik::Source::Local do
  subject(:source) { described_class.new }

  it_behaves_like "a source"

  let(:mock_files) { ["file1.txt", "dir/", "dir/file2.txt"] }

  before do
    allow(Dir).to receive(:glob).with("**/*").and_return(mock_files)
    allow(File).to receive(:directory?) { |path| path.end_with?("/") }
    allow(File).to receive(:read).and_return("test content")
  end

  describe "#expand_dir" do
    before do
      allow(Dir).to receive(:glob).with("dir/**/*").and_return(["dir/file2.txt"])
    end

    it "expands directory contents" do
      expect(source.expand_dir("dir/")).to eq(["dir/file2.txt"])
    end
  end
end
