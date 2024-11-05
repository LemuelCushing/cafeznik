require "spec_helper"

RSpec.describe Cafeznik::Source::Local do
  subject(:source) { described_class.new }

  around do |example|
    with_test_fs { example.run }
  end

  it_behaves_like "a source"

  describe "#tree" do
    it "returns all files and directories" do
      tree = source.tree

      expect(tree).to include("./")
      expect(tree).to include("src/main.rb")
      expect(tree).to include("src/lib/")
      expect(tree).to include("docs/latest")
    end

    it "respects gitignore" do
      tree = source.tree

      expect(tree).not_to include("build/main.o")
      expect(tree).not_to include(".env")
      expect(tree).not_to include("temp/")
    end

    it "handles special characters in paths" do
      expect(source.tree).to include("src/with spaces.rb")
      expect(source.tree).to include("src/special!@#.rb")
      expect(source.tree).to include("src/utf8_χξς.rb")
    end
  end

  describe "#content" do
    it "reads file content" do
      expect(source.content("README.md")).to include("Test Project")
    end

    it "handles binary files" do
      content = source.content("test/binary.dat")
      expect(content.encoding).to eq(Encoding::ASCII_8BIT)
      expect(content).not_to be_empty
    end

    it "preserves file encodings" do
      content = source.content("test/utf16.txt")
      expect(content.encode("UTF-8")).to eq("Hello World")
    end

    it "handles mixed line endings" do
      content = source.content("test/mixed_endings.txt")
      expect(content).to include("\r\n")
      expect(content).to include("\n")
    end
  end

  describe "#expand_dir" do
    it "returns all files in directory" do
      files = source.expand_dir("src/lib")

      expect(files).to include("src/lib/helper.rb")
      expect(files).to include("src/lib/nested/deep.rb")
    end

    it "follows symlinks" do
      files = source.expand_dir("docs/latest")
      expect(files).not_to be_empty
    end

    it "respects gitignore in subdirectories" do
      files = source.expand_dir("build")
      expect(files).to be_empty
    end
  end

  describe "#all_files" do
    it "returns only files, not directories" do
      files = source.all_files

      expect(files).to include("README.md")
      expect(files).to include("src/main.rb")
      expect(files).not_to include("src/")
      expect(files).not_to include("src/lib/")
    end

    it "includes hidden files not in gitignore" do
      expect(source.all_files).to include(".config/settings.yml")
    end
  end
end
