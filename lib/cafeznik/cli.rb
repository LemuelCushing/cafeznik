require "thor"

module Cafeznik
  class CLI < Thor
    def self.exit_on_failure? = true

    class_option :verbose, type: :boolean, aliases: "-v", default: false, desc: "Run in verbose mode"
    class_option :no_header, type: :boolean, default: false, desc: "Exclude headers"
    class_option :with_tree, type: :boolean, aliases: "-t", default: false, desc: "Include file tree"
    class_option :grep, type: :string, aliases: "-g", desc: "Filter files containing the specified content"

    desc "default", "Select files, copy to clipboard; use --repo/-r for GitHub repository"
    method_option :repo, type: :string, aliases: "-r", desc: "GitHub repository (owner/repo format)"

    default_task :default

    def default
      Log.verbose = options[:verbose]
      Log.info "Running in #{repo ? 'GitHub' : 'local'} mode"

      file_paths = selector.select

      Content.new( # TODO: find better name than Content, perhaps Clipboard?
        source:,
        file_paths:,
        include_headers: !options[:no_header],
        include_tree: options[:with_tree]
      ).copy_to_clipboard
    end

    private

    def repo = options[:repo]
    def grep = options[:grep]
    def source = @_source ||= repo ? Source::GitHub.new(repo:, grep:) : Source::Local.new(grep:)
    def selector = @_selector ||= Selector.new(source)
  end
end
