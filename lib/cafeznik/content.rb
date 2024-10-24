require "clipboard"

module Cafeznik
  class Content
    MAX_LINES = 10_000

    def initialize(source:, files:, include_headers:, include_tree:)
      @source = source
      @files = files
      @include_headers = include_headers
      @include_tree = include_tree
    end

    def copy_to_clipboard
      content = build_content.tap(&method(:confirm_size!))

      ::Clipboard.copy(content)
      Log.info "Copied #{@files.size} files to clipboard"
    end

    private

    def build_content = [tree_section, file_contents].compact.join("\n\n")

    def file_contents
      Log.debug "Processing #{@files.size} files"
      @files.filter_map do |file|
        content = @source.content(file)
        @include_headers ? with_header(content, file) : content
      end.join("\n\n")
    end

    def tree_section = @include_tree ? with_header(@source.tree.join("\n"), "Tree") : nil
    def with_header(content, title) = "==> #{title} <==\n#{content}"

    def confirm_size!(content)
      lines = content.lines.size
      return if lines <= MAX_LINES

      Log.warn "Content exceeds #{MAX_LINES} lines (#{lines}). Continue? (y/N)"
      exit 0 unless $stdin.gets.strip.casecmp("y").zero?
    end
  end
end
