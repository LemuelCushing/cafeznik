require "tty-command"

module Cafeznik
  class Selector
    MAX_FILES = 20

    def initialize(source)
      Log.fatal "fzf is kinda the centerpiece of this little tool here. Go install it, dear. I'll be here when you're done" unless ToolChecker.fzf_available?
      @source = source
    end

    def select(select: false, select_all: false)
      @select = select
      @select_all_cli = select_all
      skip_selection if @source.tree.empty?
      select_paths_with_fzf
        .tap { log_selection(it) if Log.verbose? }
        .then { |paths| expand_paths(paths) }
        .tap { |expanded| confirm_count!(expanded) }
    end

    private

    def skip_selection
      Log.info("No matching files found; skipping file selection.")
      exit(1)
    end

    def select_paths_with_fzf
      Log.debug "Running fzf"
      result = run_fzf_command

      # For diff source, parse the path from the custom format
      if @source.is_a?(Cafeznik::Source::Diff)
        return result.map { |line| line[/エ (.+?) \S*$/, 1] }.compact.uniq
      end

      if result.include?("./")
        @select_all = true
        ["./"]
      else
        result
      end
    rescue TTY::Command::ExitError => e
      handle_fzf_error(e)
    end

    def log_selection(paths)
      Log.debug("#{paths.size} paths selected:") do
        paths.map.with_index(1) { |p, i| "#{i}. #{p}" }.join("\n")
      end
    end

    def preview_command
      return "" unless @source.is_a?(Cafeznik::Source::Local)

      file_preview = ToolChecker.bat_available? ? "bat --style=numbers --color=always {}" : "tail -n +1 {}"
      warn = "🌳 Preview tree may be off - greps and excludes are not taken into account 🌴\n #{'=' * 100}"

      "([[ -d {} ]] && (echo '#{warn}'; tree --gitignore -C {} | head -n 50) || #{file_preview})"
    end

    def run_fzf_command
      args = ["fzf", "--multi"]
      args << "--preview \"#{preview_command}\""
      args.concat(["--bind", "start:last+select-all"]) if @select_all_cli
      args << "--sync" if @source.is_a?(Cafeznik::Source::Diff)

      TTY::Command.new(printer: Log.verbose? ? :pretty : :null)
                  .run(args.join(" "), stdin: @source.tree.join("\n"))
                  .out.split("\n")
    end

    def handle_fzf_error(error)
      exit_code = error.message.match(/exit status: (\d+)/)[1].to_i
      if exit_code == 130
        Log.info("No files selected. Exiting..")
        exit(0)
      else
        Log.error("Error running fzf: #{error.message}")
        exit(1)
      end
    end

    def expand_paths(paths)
      return paths if @source.is_a?(Cafeznik::Source::Diff)

      if @select_all
        Log.debug "Root directory selected, returning all files"
        return @source.all_files
      end

      result = paths.flat_map do |path|
        dir?(path) ? @source.expand_dir(path) : path
      end.uniq

      Log.debug "Expanded #{paths.size} paths to #{result.size} files"
      result
    end

    def confirm_count!(paths)
      Log.info "Selected #{paths.size} files"
      return paths if paths.size <= MAX_FILES

      Log.warn "Selected more than #{MAX_FILES} files (#{paths.size}). Continue? (y/N)"
      unless CLI.user_agrees?
        Log.info "Copy operation cancelled by user"
        exit 0
      end
      paths
    end

    def dir?(path) = @source.dir?(path)
  end
end
