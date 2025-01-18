require_relative "base"
require "tty-command"

module Cafeznik
  module Source
    class Local < Base
      def initialize(grep: nil, exclude: [])
        super
        Log.fatal "fd not installed. We depend on it. Get it!" unless ToolChecker.fd_available?

        @cmd = TTY::Command.new(printer: Log.verbose? ? :pretty : :null)
      end

      def tree
        return @_tree if defined?(@_tree)

        Log.debug "Building file tree#{@grep ? ' with grep filter' : ''}"
        Log.debug "Excluding patterns: #{@exclude}"

        files = @grep ? grep_filtered_files : full_tree
        files.reject! { |path| dir?(path) && all_children_excluded?(path) }
        @_tree = files.empty? ? [] : ["./"] + files.sort
        Log.debug "Files after exclusion: #{@_tree}"
        @_tree
      end

      def expand_dir(path)
        Log.debug "Expanding directory: #{path}"
        result = @cmd.run(*fd_command_args, path.chomp("/"), "--type", "f")

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

      def fd_command_args =
        [
          "fd",
          ".",
          "--hidden",
          "--follow",
          *(@exclude + [".git"]).flat_map { |e| ["--exclude", e] }
        ]

      def full_tree
        result = @cmd.run(*fd_command_args)
        result.out.split("\n")
      rescue TTY::Command::ExitError => e
        Log.error "Failed to build file tree with fd: #{e.message}"
        []
      end

      def grep_filtered_files
        Log.fatal "we're gonna need ripgrep (rg) to be installed if we're to grep around here. Go get it and come back" unless ToolChecker.rg_available?

        result = @cmd.run("rg", "--files-with-matches", @grep, ".").out.split("\n")
        Log.debug "Found #{result.size} files matching '#{@grep}'"
        result
      rescue TTY::Command::ExitError => e
        handle_rg_error(e)
      end

      # TODO: maybe there's a more elegant way to do this
      def all_children_excluded?(path) = expand_dir(path).all? { |child| exclude?(child) || (dir?(child) && all_children_excluded?(child)) }

      def handle_rg_error(error)
        if e.message.include?("exit status: 1") # TODO: this is so ugly. Is there really no way to catch the output? Probably with `run!` instead
          Log.info "No files found matching pattern '#{@grep}'"
        else
          Log.warn "Error running rg: #{error.message}"
        end
        []
      end
    end
  end
end
