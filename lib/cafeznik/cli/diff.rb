require "thor"
require_relative "../sources/diff"

module Cafeznik
  class CLI
    class Diff < Thor
      def self.exit_on_failure? = true

      option :select, type: :boolean, aliases: "-s", desc: "Interactively select files (via fzf)"
      option :select_all, type: :boolean, aliases: "-a", desc: "Interactively deselect files (via fzf)"
      option :skip_context, type: :numeric, default: 15, desc: "Context lines for skipped-file diffs"
      option :raw, type: :boolean, aliases: "-r", desc: "Copy files without diffs"
      option :output, type: :string, aliases: "-o", desc: "Output to a file instead of clipboard"
      option :repeat, type: :string, aliases: "-R", desc: "Refresh from a previous output's file list"

      def self.banner(command, _namespace, _subcommand) = "cafeznik diff #{command.usage}"

      default_task :run

      desc "run", "Default diff command"
      def run
        source = Source::Diff.new(
          raw: options[:raw],
          repeat_file: options[:repeat],
          skip_context: options[:skip_context]
        )
        file_paths = Selector.new(source).select(
          select: options[:select],
          select_all: options[:select_all]
        )

        Content.new(
          source: source,
          file_paths: file_paths,
          include_headers: !options[:no_header],
          include_tree: options[:with_tree]
        ).copy_to_clipboard(
          output_file: options[:output],
          raw: options[:raw]
        )
      end
    end
  end
end
