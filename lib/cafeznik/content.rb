require "clipboard"
require "concurrent"
require "memery"
require "tty-progressbar"

module Cafeznik
  class Content
    include Memery
    MAX_LINES = 10_000
    THREAD_COUNT = [Concurrent.processor_count, 8].min
    THREAD_TIMEOUT = 20 # seconds

    def initialize(source:, file_paths:, include_headers:, include_tree:)
      @source = source
      @file_paths = file_paths
      @include_headers = include_headers
      @include_tree = include_tree
      log_init
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

    def log_init
      Log.debug "Initializing Content" do
        <<~LOG
          Source: #{@source.class} file_paths: #{@file_paths.size}
          include_headers: #{@include_headers} include_tree: #{@include_tree}
        LOG
      end
    end

    def build_content = [tree_section, files_contents.join("\n\n")].flatten.compact.join("\n\n")

    def tree_section = @include_tree ? with_header(@source.tree.drop(1).join("\n"), "Tree") : nil
    def with_header(content, title) = "==> #{title} <==\n#{content}"

    memoize def files_contents
      Log.debug "Processing #{@file_paths.size} files in #{THREAD_COUNT} threads"

      bars = create_progress_bars
      errors = Concurrent::Hash.new
      executor = Concurrent::FixedThreadPool.new(THREAD_COUNT)

      tasks = create_file_tasks(executor, bars, errors)

      # Waits for all concurrent tasks to complete within the timeout, then returns their results as a compact array.
      results = Concurrent::Promises.zip(*tasks).value!(THREAD_TIMEOUT).compact

      executor.shutdown
      executor.wait_for_termination(THREAD_TIMEOUT)

      report_errors(errors) if errors.any?
      results
    end

    def create_progress_bars
      progress = TTY::ProgressBar::Multi.new("Processing files [:bar] :percent")
      {
        started: progress.register("Starting   [:bar] :current/:total", total: @file_paths.size),
        finished: progress.register("Completed  [:bar] :current/:total", total: @file_paths.size)
      }
    end

    def create_file_tasks(executor, bars, errors)
      @file_paths.map do |file|
        bars[:started].advance

        Concurrent::Promises.future_on(executor) do
          fetch_and_format_file(file, errors)
        ensure
          bars[:finished].advance
        end
      end
    end

    def fetch_and_format_file(file, errors)
      content = @source.content(file)
      if content && !content.empty?
        @include_headers ? with_header(content, file) : content
      end
    rescue StandardError => e
      errors[file] = e.message
      Log.error("Error fetching content for #{file}: #{e.message}")
      nil
    end

    def report_errors(errors)
      Log.warn "Completed with #{errors.size} errors:"
      errors.each.with_index(1) do |(file, message), i|
        Log.warn "  #{i}. #{file}: #{message}"
        break if i >= 5 && errors.size > 5
      end

      return unless errors.size > 5

      Log.warn "  ... and #{errors.size - 5} more errors"
    end

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
