require "clipboard"

module Cafeznik
  class Content
    MAX_LINES = 10_000

    def initialize(source:, file_paths:, include_headers:, include_tree:)
      @source = source
      @file_paths = file_paths
      @include_headers = include_headers
      @include_tree = include_tree
    end

    def copy_to_clipboard
      content = build_content.tap(&method(:confirm_size!))

      ::Clipboard.copy(content)
      Log.info "Copied #{content.lines.size} lines across #{@file_paths.size} files to clipboard"
    end

    private

    def build_content = [tree_section, file_contents].compact.join("\n\n")

    def file_contents
      Log.debug "Processing #{@file_paths.size} files"
      @file_paths.filter_map do |file|
        content = @source.content(file)
        @include_headers ? with_header(content, file) : content
      end.join("\n\n")
    end

    def tree_section = @include_tree ? with_header(@source.tree.drop(1).join("\n"), "Tree") : nil
    def with_header(content, title) = "==> #{title} <==\n#{content}"

    def confirm_size!(content)
      line_count = content.lines.size
      return if line_count <= MAX_LINES

      Log.warn "Content exceeds #{MAX_LINES} lines (#{line_count}). Continue? (y/N)"
      exit 0 unless $stdin.gets.strip.casecmp("y").zero?
    end
  end
end
