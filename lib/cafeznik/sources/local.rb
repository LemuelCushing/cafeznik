require_relative "base"
require "tty-command"

module Cafeznik
  module Source
    class Local < Base
      def initialize(grep: nil)
        super
      end

      def tree
        return @_tree if defined?(@_tree)

        Log.debug "Building file tree#{@grep ? ' with grep filter' : ''}"

        files = @grep ? grep_filtered_files : full_tree
        @_tree = ["./"] + files.sort
      end

      def all_files = tree.reject { |path| dir?(path) }

      def expand_dir(path)
        Log.debug "Expanding directory: #{path}"
        cmd = TTY::Command.new(printer: :null)
        result = cmd.run("fd", ".", path.chomp("/"), "--hidden", "--no-ignore", "--type", "f")

        result.out.split("\n").sort.uniq
      rescue TTY::Command::ExitError => e
        Log.error "Failed to expand directory with fd: #{e.message}"
        []
      end

      def dir?(path) = File.directory?(path)

      def content(path)
        File.read(path)
      rescue Errno::ENOENT
        Log.error "File not found: #{path}"
        nil
      end

      private

      def full_tree
        cmd = TTY::Command.new(printer: :null)
        result = cmd.run("fd", ".", "--hidden", "--follow", "--exclude", ".git", "--exclude", "node_modules", "--exclude", "vendor")
        result.out.split("\n")
      rescue TTY::Command::ExitError => e
        Log.error "Failed to build file tree with fd: #{e.message}"
        []
      end

      def grep_filtered_files
        cmd = TTY::Command.new(printer: :null)
        result = cmd.run("rg", "--files-with-matches", @grep, ".").out.split("\n")
        Log.debug "Found #{result.size} files matching '#{@grep}'"
        result
      rescue TTY::Command::ExitError => e
        Log.warn "Error running rg: #{e.message}"
        []
      end

      def fd_available? = system("command -v fd > /dev/null 2>&1")
      # TODO: add rg check
    end
  end
end
