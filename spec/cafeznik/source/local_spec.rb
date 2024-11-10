require "spec_helper"
require "tmpdir"

RSpec.describe Cafeznik::Source::Local do
  subject(:source) { described_class.new(grep:) }

  let(:grep) { nil }

  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        system("git init --quiet")
        system("git config --local user.email 'test@example.com'")
        system("git config --local user.name 'Test User'")
        example.run
      end
    end
  end

  before do
    # Create standard directory structure
    %w[
      src/lib/nested
      docs
      .config
      .hidden_dir
    ].each { |dir| FileUtils.mkdir_p(dir) }

    # Create standard files
    {
      "README.md" => "# Test Project",
      "src/main.rb" => "puts 'Hello, World!'",
      "src/lib/helper.rb" => "module Helper; end",
      "src/lib/nested/deep.rb" => "# Deep nested file",
      "docs/latest" => "# Latest Documentation",
      ".config/settings.yml" => "setting: true",
      ".hidden_dir/.hidden_file" => "secret",
      ".hidden_dir/regular_file" => "visible"
    }.each { |path, content| File.write(path, content) }

    # Set up ignored files
    File.write(".gitignore", "ignored/\n*.log")
    FileUtils.mkdir_p("ignored")
    File.write("ignored/secret.txt", "ignored content")
    File.write("debug.log", "debug info")
    File.write("src/error.log", "error info")
  end

  shared_examples "respects visibility rules" do
    it "includes hidden files" do
      results = source.public_send(described_method)
      expect(results).to include(".config/settings.yml")
    end

    it "excludes ignored files" do
      results = source.public_send(described_method)
      expect(results).not_to include("ignored/secret.txt", "debug.log", "src/error.log")
    end
  end

  describe "#tree" do
    let(:described_method) { :tree }

    it "includes root directory marker" do
      expect(source.tree).to include("./")
    end

    it "includes files and directories" do
      expect(source.tree).to include("src/main.rb", "src/lib/", "docs/latest")
    end

    context "with special characters" do
      before do
        FileUtils.mkdir_p("special")
        {
          "special/with spaces.rb" => "# Spacey",
          "special/special!@#.rb" => "# Special!",
          "special/utf8_χξς.rb" => "# Greek"
        }.each { |path, content| File.write(path, content) }
      end

      it "handles special characters in paths" do
        expect(source.tree).to include(
          "special/with spaces.rb",
          "special/special!@#.rb",
          "special/utf8_χξς.rb"
        )
      end
    end

    include_examples "respects visibility rules"
  end

  describe "#all_files" do
    let(:described_method) { :all_files }

    it "excludes directories" do
      expect(source.all_files).not_to include("src/", "src/lib/")
    end

    it "includes all regular files" do
      expect(source.all_files).to include("README.md", "src/main.rb")
    end

    include_examples "respects visibility rules"
  end

  describe "#expand_dir" do
    it "returns files in directory" do
      expect(source.expand_dir("src/lib")).to contain_exactly(
        "src/lib/helper.rb",
        "src/lib/nested/deep.rb"
      )
    end

    it "follows symlinks" do
      FileUtils.ln_s("docs", "linked_docs")
      expect(source.expand_dir("linked_docs")).to include("linked_docs/latest")
    end

    it "expands hidden directories" do
      expect(source.expand_dir(".hidden_dir")).to contain_exactly(
        ".hidden_dir/.hidden_file",
        ".hidden_dir/regular_file"
      )
    end

    it "excludes ignored contents from non-ignored directory" do
      FileUtils.mkdir_p("src/ignored")
      File.write("src/ignored/test.txt", "content")

      expect(source.expand_dir("src")).not_to include("src/ignored/test.txt")
    end
  end

  describe "#content" do
    it "reads file content" do
      expect(source.content("README.md")).to eq("# Test Project")
    end

    it "handles empty files" do
      File.write("empty.txt", "")
      expect(source.content("empty.txt")).to eq("")
    end

    it "handles mixed line endings" do
      content = "line1\r\nline2\nline3\r\nline4\n"
      File.write("mixed.txt", content)
      expect(source.content("mixed.txt")).to eq(content)
    end

    context "with missing files" do
      before do
        allow(Cafeznik::Log).to receive(:error)
      end

      it "logs an error" do
        source.content("nonexistent.txt")
        expect(Cafeznik::Log).to have_received(:error).with("File not found: nonexistent.txt")
      end

      it "returns nil" do
        expect(source.content("nonexistent.txt")).to be_nil
      end
    end

    context "with binary files" do
      let(:binary_content) { [0, 1, 2].pack("C*") }

      before do
        File.binwrite("binary.dat", binary_content)
      end

      it "preserves binary encoding", skip: "Need to implement proper binary file handling" do
        expect(source.content("binary.dat").encoding).to eq(Encoding::ASCII_8BIT)
      end

      it "preserves binary content", skip: "Need to implement proper binary file handling" do
        expect(source.content("binary.dat").bytes).to eq(binary_content.bytes)
      end
    end
  end

  describe "with grep filter" do
    let(:grep) { "Helper" }

    before do
      File.write("src/other.rb", "class Other; end")
      File.write("src/with_helper.rb", "include Helper")
    end

    it "only includes matching files" do
      expect(source.tree).to include("./src/lib/helper.rb", "./src/with_helper.rb")
    end

    context "with no matches" do
      let(:grep) { "NonexistentPattern" }

      it "returns only root" do
        expect(source.tree).to eq(["./"])
      end
    end
  end
end
