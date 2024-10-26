RSpec.shared_examples "a CLI command" do |expected_mode|
  before do
    allow(Cafeznik::Log).to receive(:info)
    allow(mock_content).to receive(:copy_to_clipboard)
  end

  it "identifies the correct mode" do
    subject
    expect(Cafeznik::Log).to have_received(:info).with(/Running in #{expected_mode} mode/)
  end

  it "copies content to clipboard" do
    subject
    expect(mock_content).to have_received(:copy_to_clipboard)
  end
end
