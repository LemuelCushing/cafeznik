require "clipboard"
require "memery"

module Cafeznik
  class Content
    include Memery
    MAX_LINES = 10_000

    def initialize(source:, file_paths:, include_headers:, include_tree:)
      Log.debug "Initializing Content" do
        <<~LOG
          Source: #{source.class} file_paths: #{file_paths.size}
          include_headers: #{include_headers} include_tree: #{include_tree}
        LOG
      end
      @source = source
      @file_paths = file_paths
      @include_headers = include_headers
      @include_tree = include_tree
    end

    def copy_to_clipboard
      Log.debug "Copying content to clipboard"
      @content = build_content

      return Log.info("Copy operation cancelled by user") unless confirm_size!

      ::Clipboard.copy(@content)

      skipped_files = @file_paths.size - files_contents.size

      log_message = "Copied #{@content.lines.size} lines across #{files_contents.size} files"
      log_message << " (skipped #{skipped_files} empty)" if skipped_files.positive?

      Log.info("#{log_message} to clipboard")
    end

    private

    memoize def build_content = [tree_section, files_contents.join("\n\n")].flatten.compact.join("\n\n")

    memoize def files_contents
      Log.debug "Processing #{@file_paths.size} files"
      @file_paths.each_with_object([]) do |file, memo|
        content = @source.content(file)
        memo << (@include_headers ? with_header(content, file) : content) unless content.empty?
      rescue StandardError => e
        Log.error("Error fetching content for #{file}: #{e.message}")
        nil
      end
    end

    memoize def tree_section = @include_tree ? with_header(@source.tree.drop(1).join("\n"), "Tree") : nil
    def with_header(content, title) = "==> #{title} <==\n#{content}"

    def confirm_size!
      line_count = @content.lines.size
      return true if line_count <= MAX_LINES

      if @include_tree && suggest_tree_removal?
        Log.warn "Content exceeds #{MAX_LINES} lines (#{line_count}). Try cutting out the tree? (y/N)"
        @include_tree = false
        @content = build_content
        return confirm_size! if CLI.user_agrees?
      end

      Log.warn "Content exceeds #{MAX_LINES} lines (#{line_count}). Proceed? (y/N)"
      CLI.user_agrees?
    end

    def suggest_tree_removal? = @content.lines.size <= MAX_LINES + @source.tree.size - 1
  end
end
