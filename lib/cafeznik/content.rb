require "clipboard"

module Cafeznik
  class Content
    MAX_LINES = 10_000

    def initialize(source:, file_paths:, include_headers:, include_tree:)
      Log.debug "Initializing Content" do
        "Source: #{source}\n file_paths: #{file_paths}\n include_headers: #{include_headers}\n include_tree: #{include_tree}\n"
      end
      @source = source
      @file_paths = file_paths
      @include_headers = include_headers
      @include_tree = include_tree
    end

    def copy_to_clipboard
      Log.debug "Copying content to clipboard"
      content = build_content

      unless confirm_size!(content)
        Log.info "Copy operation cancelled by user"
        return
      end

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
      rescue StandardError => e
        Log.error("Error fetching content for #{file}: #{e.message}")
        nil
      end.join("\n\n")
    end

    def tree_section = @include_tree ? with_header(@source.tree.drop(1).join("\n"), "Tree") : nil
    def with_header(content, title) = "==> #{title} <==\n#{content}"

    def confirm_size!(content)
      line_count = content.lines.size
      return true if line_count <= MAX_LINES

      if @include_tree && suggest_tree_removal?(line_count)
        Log.warn "Content exceeds #{MAX_LINES} lines (#{line_count}). Try cutting out the tree? (y/N)"
        @include_tree = false
        return confirm_size!(build_content) if CLI.user_agrees?
      end

      Log.warn "Content exceeds #{MAX_LINES} lines (#{line_count}). Proceed? (y/N)"
      CLI.user_agrees?
    end

    def suggest_tree_removal?(line_count) = line_count <= MAX_LINES + @source.tree.size - 1
  end
end
