require_relative "base"
require "tty-command"

module Cafeznik
  module Source
    class Local < Base
      def initialize(grep: nil)
        super
        raise "fd not installed. We depend on it. Get it!" unless fd_available?

        @cmd = TTY::Command.new(printer: :null)
      end

      def tree
        return @_tree if defined?(@_tree)

        Log.debug "Building file tree#{@grep ? ' with grep filter' : ''}"

        files = @grep ? grep_filtered_files : full_tree
        @_tree = files.empty? ? [] : ["./"] + files.sort
      end

      def expand_dir(path)
        Log.debug "Expanding directory: #{path}"
        result = @cmd.run("fd", ".", path.chomp("/"),
                          "--hidden", "--follow",
                          "--type", "f",
                          "--exclude", ".git")

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
        result = @cmd.run("fd", ".",
                          "--hidden", "--follow",
                          "--exclude", ".git")
        result.out.split("\n")
      rescue TTY::Command::ExitError => e
        Log.error "Failed to build file tree with fd: #{e.message}"
        []
      end

      def grep_filtered_files
        raise "we're gonna need ripgrep (rg) to be installed if we're to grep around here. Go get it and come back" unless rg_available?

        result = @cmd.run("rg", "--files-with-matches", @grep, ".").out.split("\n")
        Log.debug "Found #{result.size} files matching '#{@grep}'"
        result
      rescue TTY::Command::ExitError => e
        if e.message.include?("exit status: 1") # TODO: this is so ugly. Is there really no way to catch the output? Probably with `run!` instead
          Log.info "No files found matching pattern '#{@grep}'"
        else
          Log.warn "Error running rg: #{e.message}"
        end
        []
      end

      def fd_available? = system("command -v fd > /dev/null 2>&1")
      def rg_available? = system("command -v rg > /dev/null 2>&1")
    end
  end
end
