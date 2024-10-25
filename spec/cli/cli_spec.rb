require "spec_helper"
require_relative "../../lib/cafeznik"

RSpec.describe Cafeznik::CLI do
  subject(:cli) { described_class.start(args) }

  let(:args) { ["default"] }
  let(:mock_selector) { instance_double(Cafeznik::Selector) }
  let(:mock_content) { instance_double(Cafeznik::Content) }
  let(:logger_output) { StringIO.new }

  before do
    allow(Cafeznik::Selector).to receive(:new).and_return(mock_selector)
    allow(Cafeznik::Content).to receive(:new).and_return(mock_content)
    allow(mock_selector).to receive(:select).and_return(["file1.txt"])
    allow(mock_content).to receive(:copy_to_clipboard)
    allow(Cafeznik::Log).to receive(:logger).and_return(Logger.new(logger_output))
  end

  it_behaves_like "a CLI command", "local"

  context "with --repo option" do
    let(:args) { ["default", "--repo", "owner/repo"] }
    it_behaves_like "a CLI command", "GitHub"
  end

  describe "options handling" do
    it "respects --no-header" do
      described_class.start(["default", "--no-header"])
      expect(Cafeznik::Content).to have_received(:new).with(hash_including(include_headers: false))
    end

    it "respects --with-tree" do
      described_class.start(["default", "--with-tree"])
      expect(Cafeznik::Content).to have_received(:new).with(hash_including(include_tree: true))
    end

    it "enables verbose logging" do
      allow(Cafeznik::Log).to receive(:verbose=).and_call_original
      allow(Cafeznik::Log).to receive(:debug).with("Verbose mode enabled")

      described_class.start(["default", "--verbose"])

      expect(Cafeznik::Log).to have_received(:verbose=).with(true)
    end
  end
end
