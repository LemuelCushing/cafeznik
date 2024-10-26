require "spec_helper"

RSpec.describe Cafeznik::Source::Local do
  subject(:source) { described_class.new }

  let(:mock_files) { ["file1.txt", "dir/", "dir/file2.txt"] }
  let(:mock_gitignore) { instance_double(FastIgnore) }

  before do
    allow(Dir).to receive(:glob).with("**/*", File::FNM_DOTMATCH).and_return(mock_files)
    allow(File).to receive(:directory?) { |path| path.end_with?("/") }
    allow(File).to receive(:read).and_return("test content")
    allow(FastIgnore).to receive(:new).and_return(mock_gitignore)
    allow(mock_gitignore).to receive(:allowed?).and_return(true)
  end

  it_behaves_like "a source"

  describe "#expand_dir" do
    before do
      allow(Dir).to receive(:glob).with("dir/**/*", File::FNM_DOTMATCH).and_return(["dir/file2.txt"])
      allow(mock_gitignore).to receive(:allowed?).with("dir/file2.txt").and_return(true)
    end

    it "expands directory contents" do
      expect(source.expand_dir("dir")).to eq(["dir/file2.txt"])
    end

    context "with ignored files" do
      before do
        allow(mock_gitignore).to receive(:allowed?).with("dir/file2.txt").and_return(false)
      end

      it "excludes ignored files" do
        expect(source.expand_dir("dir")).to be_empty
      end
    end
  end
end
