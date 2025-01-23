require "tty-command"

module Cafeznik
  class Selector
    MAX_FILES = 20

    def initialize(source)
      @source = source
      Log.fatal "fzf is kinda the centerpiece of this little tool here. Go install, deal. I'll be here when you're done" unless ToolChecker.fzf_available?
    end

    def select
      skip_selection if @source.tree.empty?
      select_paths_with_fzf
        .then { |paths| expand_paths(paths) }
        .tap { |expanded| confirm_count!(expanded) }
    end

    private

    def skip_selection = Log.info("No matching files found; skipping file selection.") && exit(1)

    def select_paths_with_fzf
      Log.debug "Running fzf"
      run_fzf_command.then { |selected| selected.include?("./") ? [:all_files] : selected }
    rescue TTY::Command::ExitError => e
      handle_fzf_error(e)
    end

    def run_fzf_command = TTY::Command.new(printer: Log.verbose? ? :pretty : :null)
                                      .run("fzf --multi", stdin: @source.tree.join("\n"))
                                      .out.split("\n")

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
      return @source.all_files.reject { |path| @source.exclude?(path) } if paths == [:all_files]

      paths.flat_map do |path|
        dir?(path) ? @source.expand_dir(path) : path
      end.uniq
    end

    def confirm_count!(paths)
      Log.info "Selected #{paths.size} files"
      return paths if paths.size <= MAX_FILES

      Log.warn "Selected more than #{MAX_FILES} files. Continue? (y/N)"
      unless CLI.user_agrees?
        Log.info "Copy operation cancelled by user"
        exit 0
      end
      paths
    end

    def dir?(path) = @source.dir?(path)
  end
end
