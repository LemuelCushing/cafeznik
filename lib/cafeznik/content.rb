require "clipboard"
require "concurrent"
require "memery"

module Cafeznik
  class Content
    include Memery
    MAX_LINES = 10_000
    THREAD_COUNT = [Concurrent.processor_count, 8].min
    THREAD_TIMEOUT = 60 # seconds

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

    def build_content = [tree_section, files_contents.join("\n\n")].flatten.compact.join("\n\n")

    # memoize def files_contents
    #   Log.debug "Processing #{@file_paths.size} files"
    #   @file_paths.each_with_object([]) do |file, memo|
    #     content = @source.content(file)
    #     memo << (@include_headers ? with_header(content, file) : content) unless content.empty?
    #   rescue StandardError => e
    #     Log.error("Error fetching content for #{file}: #{e.message}")
    #     nil
    #   end
    # end

    memoize def files_contents
      Log.debug "Processing #{@file_paths.size} files using #{THREAD_COUNT} threads"

      results = []
      mutex = Mutex.new
      errors = []
      progress = ProgressTracker.new(@file_paths.size)

      thread_buffers = {}

      # Create thread pool
      pool = Concurrent::FixedThreadPool.new(THREAD_COUNT)

      @file_paths.each do |file|
        pool.post do
          thread_id = Thread.current.object_id
          thread_buffers[thread_id] ||= []
          local_buffer = thread_buffers[thread_id]

          begin
            content = @source.content(file)
            unless content.to_s.empty?
              formatted = @include_headers ? with_header(content, file) : content
              local_buffer << formatted
            end
            progress.increment
          rescue StandardError => e
            Log.error("Error fetching content for #{file}: #{e.message}")
            mutex.synchronize do
              errors << "Error with #{file}: #{e.message}"
            end
          end
        end
      end

      pool.shutdown
      unless pool.wait_for_termination(THREAD_TIMEOUT)
        Log.warn "Thread pool did not shut down within #{THREAD_TIMEOUT} seconds, forcing termination"
        pool.kill
      end

      # Collect results from thread-local buffers
      thread_buffers.each_value do |buffer|
        results.concat(buffer)
      end

      Log.warn "Completed with #{errors.size} errors" if errors.any?
      results
    end
    def tree_section = @include_tree ? with_header(@source.tree.drop(1).join("\n"), "Tree") : nil
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

module Cafeznik
  class ProgressTracker
    def initialize(total, logger)
      @total = total
      @logger = logger
      @current = 0
      @last_percent = 0
      @start_time = Time.now
      @mutex = Mutex.new
    end

    def increment
      @mutex.synchronize do
        @current += 1
        percent = (@current.to_f / @total * 100).round

        if percent > @last_percent || @current == @total
          elapsed = Time.now - @start_time
          rate = @current / elapsed

          @logger.info "Processing: #{percent}% complete (#{@current}/#{@total} files, #{rate.round(1)} files/sec)"
          @last_percent = percent
        end
      end
    end
  end
end
