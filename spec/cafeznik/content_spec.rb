require "spec_helper"

RSpec.describe Cafeznik::Content do
  subject(:content) { described_class.new(**params) }

  let(:source) { instance_double(Cafeznik::Source::Local) }
  let(:files) { ["file1.txt"] }
  let(:base_params) { { source:, files:, include_headers: true, include_tree: false } }
  let(:params) { base_params }

  before do
    allow(source).to receive(:content).with("file1.txt").and_return("content")
    allow(source).to receive(:tree).and_return(["./", "file1.txt"])
    allow(Clipboard).to receive(:copy)
  end

  describe "#copy_to_clipboard" do
    it "copies formatted content with headers" do
      content.copy_to_clipboard
      expect(Clipboard).to have_received(:copy).with("==> file1.txt <==\ncontent")
    end

    context "without headers" do
      let(:params) { base_params.merge(include_headers: false) }

      it "copies raw content" do
        content.copy_to_clipboard
        expect(Clipboard).to have_received(:copy).with("content")
      end
    end

    context "with tree" do
      let(:params) { base_params.merge(include_tree: true) } # TODO: see if there is an even more elegant way to modify the params

      it "includes tree in content" do
        content.copy_to_clipboard
        expect(Clipboard).to have_received(:copy).with(/==> Tree <==.*==> file1.txt <==/m)
      end
    end
  end
end
