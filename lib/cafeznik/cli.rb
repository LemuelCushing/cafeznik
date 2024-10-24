require "thor"

module Cafeznik
  class CLI < Thor
    def self.exit_on_failure? = true

    class_option :verbose, type: :boolean, aliases: "-v", default: false, desc: "Run in verbose mode"
    class_option :no_header, type: :boolean, default: false, desc: "Exclude headers"
    class_option :with_tree, type: :boolean, aliases: "-t", default: false, desc: "Include file tree"

    desc "default", "Select files, copy to clipboard; use --repo/-r for GitHub repository"
    method_option :repo, type: :string, aliases: "-r", desc: "GitHub repository (owner/repo format)"

    default_task :default

    def default
      repo = options[:repo]

      Log.verbose = options[:verbose]
      Log.info "Running in #{repo ? 'GitHub' : 'local'} mode"

      source = repo ? Source::GitHub.new(repo) : Source::Local.new
      files = Selector.new(source).select

      Content.new(
        source:,
        files:,
        include_headers: !options[:no_header],
        include_tree: options[:with_tree]
      ).copy_to_clipboard
    end
  end
end
