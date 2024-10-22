# require 'spec_helper'
require_relative '../../lib/cafeznik/cli'

RSpec.describe Cafeznik::CLI, type: :cli do
  include_context "cli"

  let(:described_class) { Cafeznik::CLI }
  let(:repo) { 'owner/repo' }
  let(:main_repo) { 'main' }

  before do
    mock_octokit = double('Octokit::Client')
    allow(Octokit::Client).to receive(:new).and_return(mock_octokit)
    allow(mock_octokit).to receive(:repository).with(repo).and_return(double("Sawyer::Resource", default_branch: 'main'))
    allow(mock_octokit).to receive(:tree).with(repo, 'main', recursive: true).and_return(double("Sawyer::Resource", tree: []))
    allow(mock_octokit).to receive(:contents).with(repo, path: anything).and_return({ content: Base64.encode64("File content") })
    
    mock_tty = double('TTY::Command')
    allow(TTY::Command).to receive(:new).and_return(mock_tty)
    allow(mock_tty).to receive(:run).and_return(double('Result', out: "mocked_output"))
    
    allow(Clipboard).to receive(:copy).and_return(true)
  end

  shared_examples "a CLI command" do |args, expected_output|
    it "outputs the expected message" do
      expect { described_class.start(args) }.to output(/#{expected_output}/).to_stdout
    end
  end

  describe "Help Command" do
    it_behaves_like "a CLI command", ['--help'], "Commands:"
  end

  describe "GitHub Mode Identification" do
    context "when --repo is provided" do
      it "identifies as GitHub mode" do
        output = capture_stdout {described_class.start(['default', '--repo', repo]) }
        expect(output).to include("GitHub mode")
      end
    end

    context "when --repo is not provided" do
      it "identifies as local mode" do
        output = capture_stdout {described_class.start(['default']) }
        expect(output).to include("local mode")
      end
    end
  end
end
