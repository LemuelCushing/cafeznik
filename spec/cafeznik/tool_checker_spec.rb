require "spec_helper"

RSpec.describe Cafeznik::ToolChecker do
  it "finds fdfind when fd is absent" do
    allow(described_class).to receive(:system).and_return(false)
    allow(described_class).to receive(:system).with(/fdfind/).and_return(true)
    expect(described_class.fd_available?).to be(true)
    expect(described_class.resolve("fd")).to eq("fdfind")
  end
end
