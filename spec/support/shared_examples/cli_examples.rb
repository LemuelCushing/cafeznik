RSpec.shared_examples "a CLI command" do |expected_mode|
  it "identifies the correct mode" do
    expect(Cafeznik::Log).to receive(:info).with(/Running in #{expected_mode} mode/)
    subject
  end

  it "copies content to clipboard" do
    expect(mock_content).to receive(:copy_to_clipboard)
    subject
  end
end
