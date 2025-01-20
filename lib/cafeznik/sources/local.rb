require_relative "base"
require "tty-command"
require "memery"

module Cafeznik
  module Source
    class Local < Base
      include Memery
      def initialize(grep: nil, exclude: [])
        super
        Log.fatal "fd not installed. We depend on it. Get it!" unless ToolChecker.fd_available?

        @cmd = TTY::Command.new(printer: Log.verbose? ? :pretty : :null)
      end

      memoize def tree
        Log.debug "Building file tree#{@grep ? ' with grep filter' : ''}, #{@exclude ? "excluding: #{@exclude.join(',')}" : ''}"
        files = @grep ? grepped_files : full_tree
        files.empty? ? [] : ["./"] + files.sort
      end

      def expand_dir(path) = run_fd(path, "--type", "f")
      def dir?(path) = File.directory?(path)

      def content(path) = begin
        File.read(path)
      rescue StandardError
        Log.error("File not found: #{path}")
        nil
      end

      memoize def exclude?(path) = @exclude.any? { File.fnmatch?(it, File.basename(path), File::FNM_PATHNAME) }
      memoize def full_tree = fd_command(".")

      private

      memoize def grepped_files
        Log.fatal "rg required for grep functionality. Install and retry." unless ToolChecker.rg_available?
        files = run_command(["rg", "--files-with-matches", @grep, "."]).tap { Log.debug "Grep matched #{it.size} files" }
        files.reject { exclude?(it) }
      rescue TTY::Command::ExitError => e
        handle_grep_error(e)
      end

      def run_fd(path, *args)
        run_command(fd_command(path, *args)).tap { Log.debug "FD fetched #{it.size} entries from #{path}" }
      rescue TTY::Command::ExitError => e
        Log.error("FD error: #{e.message}")
        []
      end

      def fd_command(path, *args)
        run_command ["fd", path.chomp("/"), "--hidden", "--follow", *exclusion_args, *args]
      end

      def run_command(args) = @cmd.run(*args).out.split("\n")

      def handle_grep_error(error)
        Log.info "No grep matches for '#{@grep}'" if error.message.include?("exit status: 1")
        Log.warn "RG error: #{error.message}" unless error.message.include?("exit status: 1")
        []
      end

      def exclusion_args = (@exclude + [".git"]).flat_map { ["--exclude", it] }
    end
  end
end
