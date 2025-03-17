require "spec_helper"
require "tmpdir"

RSpec.describe Cafeznik::Source::Local do
  subject(:source) { described_class.new(grep:) }

  let(:grep) { nil }

  around do |example|
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        create_local_file_structure
        system("git init --quiet")
        system("git config --local user.email 'test@example.com'")
        system("git config --local user.name 'Test User'")
        example.run
      end
    end
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

    it "excludes the usual suspects" do
      results = source.public_send(described_method)
      expect(results).not_to include("assets/image.png", "assets/document.pdf")
    end

    it "does not ignore metadata files" do
      results = source.public_send(described_method)
      expect(results).to include("assets/image.png.meta")
    end
  end

  describe "#tree" do
    let(:described_method) { :tree }

    it "includes root directory marker" do
      expect(source.tree).to include("./")
    end

    it "includes files and directories" do
      expect(source.tree).to include("src/main.rb", "src/lib/", "docs/latest", "docs/old_docs")
    end

    context "with special characters" do
      it "handles special characters in paths" do
        expect(source.tree).to include(
          "special/with spaces.rb",
          "special/special!@#.rb",
          "special/ut-fu_χ𓆑𒀭.rb"
        )
      end
    end

    include_examples "respects visibility rules"
  end

  describe "#all_files" do
    let(:described_method) { :all_files }

    it "excludes directories" do
      expect(source.all_files).not_to include(a_string_ending_with("/"))
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
  end

  describe "with grep filter" do
    let(:grep) { "Helper" }

    it "only includes matching files" do
      expect(source.tree).to include("src/lib/helper.rb", "src/with_helper.rb")
    end

    context "with exclusions applied" do
      subject(:source) { described_class.new(grep:, exclude: ["*.rb"]) }

      it "respects exclusions even when files match grep" do
        expect(source.tree).not_to include("src/lib/helper.rb", "src/with_helper.rb")
      end
    end

    context "with no matches" do
      let(:grep) { "NonexistentPattern" }

      it "returns empty array" do
        expect(source.tree).to eq([])
      end
    end
  end

  describe "with excluded files" do
    [
      { exclude: ["old_docs"], excluded_items: ["docs/old_docs"] },
      { exclude: ["*.yml"], excluded_items: [".config/settings.yml"] },
      { exclude: [".hidden_dir/"], excluded_items: [".hidden_dir/.hidden_file", ".hidden_dir/regular_file"] }
    ].each do |example|
      context "when excluding #{example[:exclude].join(', ')}" do
        subject(:source) { described_class.new(exclude: example[:exclude]) }

        it "excludes the specified items" do
          expect(source.tree).not_to include(*example[:excluded_items])
        end
      end
    end
  end

  it "handles symlink loops" do
    FileUtils.mkdir_p("loop_dir")
    FileUtils.ln_s("../loop_dir", "loop_dir/loop")

    expect { source.expand_dir("loop_dir") }.not_to raise_error
  end
end
