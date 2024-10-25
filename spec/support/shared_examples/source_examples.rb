RSpec.shared_examples "a source" do
  let(:source) { described_class.name.include?("GitHub") ? described_class.new("owner/repo") : described_class.new } # TODO: this can be more elegant

  it { is_expected.to respond_to(:tree, :all_files, :expand_dir, :content) }

  describe "#tree" do
    it "returns an array starting with ./" do
      expect(source.tree.first).to eq("./")
    end
  end

  describe "#all_files" do
    it "excludes directory paths" do
      expect(source.all_files).not_to include(end_with("/"))
    end
  end
end
