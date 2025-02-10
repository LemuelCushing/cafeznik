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

      def expand_dir(path)
        if path == "./"
          return grepped_files if @grep

          return full_tree
        end

        list_paths(path, files_only: true)
      end

      def dir?(path) = File.directory?(path)

      def content(path)
        return nil if dir?(path) || exclude?(path)

        File.read(path)
      rescue StandardError
        Log.error("File not found: #{path}")
        nil
      end

      memoize def exclude?(path)
        @exclude.any? { |p| File.fnmatch?(p, File.basename(path), File::FNM_PATHNAME) }
      end

      def full_tree = list_paths
      def all_files = @grep ? grepped_files : list_paths(files_only: true)

      private

      def list_paths(path = nil, files_only: false)
        args = ["--hidden", "--follow",
                (["--type", "f"] if files_only),
                "--full-path",
                ("--strip-cwd-prefix" unless path),
                *exclusion_args,
                ".", path].flatten.compact
        run_cmd("fd", args)
      rescue TTY::Command::ExitError => e
        Log.error("FD error: #{e.message}") unless e.message.include?("exit status: 1")
        []
      end

      def exclusion_args = (@exclude + [".git"]).flat_map { |p| ["--exclude", p] }

      memoize def grepped_files
        Log.fatal "rg required for grep functionality. Install and retry." unless ToolChecker.rg_available?

        args = @exclude.flat_map { |p| ["-g", "!#{p}"] }
        result = run_cmd("rg", ["--files-with-matches", @grep, ".", *args])
        result.map { |f| f.delete_prefix("./") }
      rescue TTY::Command::ExitError => e
        Log.error("RG error: #{e.message}") unless e.message.include?("exit status: 1")
        []
      end

      def run_cmd(cmd, args) = @cmd.run(cmd, *args).out.split("\n")
    end
  end
end
