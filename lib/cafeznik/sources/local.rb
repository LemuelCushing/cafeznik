require_relative "base"
require "tty-command"

module Cafeznik
  module Source
    class Local < Base
      def tree
        Log.debug "Building file tree with fd command"

        raise "fd not available" unless fd_available?

        cmd = TTY::Command.new(printer: :null)
        result = cmd.run("fd", ".", "--hidden", "--type", "f", "--type", "d", "--exclude", ".git", "--exclude", "node_modules", "--exclude", "vendor")

        @_tree ||= ["./"] + result.out.split("\n").sort
      rescue TTY::Command::ExitError => e
        Log.error "Failed to build file tree with fd: #{e.message}"
        []
      end

      def all_files
        tree.reject { |path| File.directory?(path) }
      end

      def expand_dir(path)
        Log.debug "Expanding directory: #{path}"
        cmd = TTY::Command.new(printer: :null)
        result = cmd.run("fd", ".", path.chomp("/"), "--hidden", "--no-ignore", "--type", "f")

        result.out.split("\n").sort
      rescue TTY::Command::ExitError => e
        Log.error "Failed to expand directory with fd: #{e.message}"
        []
      end

      def dir?(path)
        File.directory?(path)
      end

      # TODO: rename to file_contents
      def content(path)
        File.read(path)
      rescue Errno::ENOENT
        Log.error "File not found: #{path}"
        nil
      end

      private

      def fd_available? = system("command -v fd > /dev/null 2>&1")
    end
  end
end
