require "tty-command"

module Cafeznik
  class Selector
    MAX_FILES = 20

    def initialize(source)
      @source = source
    end

    def select = (@source.tree.empty? ? skip_selection : run_fzf)
      .tap(&method(:log_selection))
      .then { |paths| expand_paths(paths) }
      .tap { |expanded| confirm_count!(expanded) }

    private

    def skip_selection = Log.info("No matching files found; skipping file selection.") && []

    def run_fzf
      cmd = TTY::Command.new(printer: Log.verbose? ? :pretty : :null)
      Log.debug "Running fzf"
      selected = cmd.run("fzf --multi", stdin: @source.tree.join("\n")).out.split("\n")
      selected.include?("./") ? [:all_files] : selected
    rescue TTY::Command::ExitError
      Log.info "No files selected, exiting."
      exit 0
    end

    def log_selection(paths)
      Log.debug("#{paths.size} paths selected:") do
        paths.map.with_index(1) { |p, i| "#{i}. #{p}" }.join("\n")
      end
    end

    def expand_paths(paths)
      return @source.all_files if paths == [:all_files]

      paths.flat_map { |path| dir?(path) ? @source.expand_dir(path) : path }.uniq
    end

    def confirm_count!(paths)
      Log.info "Selected #{paths.size} files"
      return paths if paths.size <= MAX_FILES

      Log.warn "Selected more than #{MAX_FILES} files. Continue? (y/N)"
      exit 0 unless $stdin.gets.strip.casecmp("y").zero?
      paths
    end

    def dir?(path) = @source.dir?(path)
  end
end
