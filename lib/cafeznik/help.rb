# rubocop:disable Metrics/MethodLength
module Cafeznik
  module Help
    def self.display(cli)
      version = Cafeznik::VERSION
      banner = <<~BANNER
        ╔◤ CΛFΞΖПIK v#{version} ◢═══════════╗
        ║─┳─ interactive ║ code2pilfer ║
        ╚═╂══════════════╩══════ꙮ══════╝
      BANNER
      cli.say banner, :green
      cli.say "\n"

      cli.say_status("Usage", "cafeznik [OPTIONS]", :yellow)
      cli.print_wrapped(
        "The default behavior (local mode) is invoked when no subcommand is given. " \
        "To use GitHub mode, specify a repository with the --repo option.", indent: 2
      )
      cli.say "\n"

      cli.say_status("Modes", "", :blue)
      modes = [
        ["Local Mode (default)", "Copies files from your local file system."],
        ["GitHub Mode", "Copies files from a GitHub repository (specify with --repo owner/repo)."]
      ]
      cli.print_table(modes, indent: 2, borders: true)
      cli.say "\n"

      cli.say_status("Options", "", :cyan)
      options = [
        ["--repo, -r",      "Specify a GitHub repository (owner/repo format)"],
        ["--grep, -g",      "Filter files: include only those containing a specific pattern"],
        ["--exclude",       "Exclude files/folders matching given glob patterns"],
        ["--with_tree, -t", "Include the file tree structure in the output"],
        ["--no_header",     "Exclude file headers from the copied content"],
        ["--version, -v",   "Display version information"],
        ["--verbose",       "Enable verbose logging (detailed output)"],
        ["-h/help", "Display this help message"]
      ]
      cli.print_table(options, indent: 2, borders: false)
      cli.say "\n"

      cli.say_status("Examples", "", :green)
      examples = [
        ["cafeznik", "# Runs in local mode, letting you select local files to copy to the clipboard"],
        ["cafeznik --repo LemuelCushing/cafeznik", "# Runs in GitHub mode and gets the repo"],
        ["cafeznik --no_header --with_tree", "# Does not include headers and includes the file tree"],
        ["cafeznik --grep \"ChunkyBacon.new\"", "# Only includes files where new ChunkyBacon are chunked"]
      ]
      cli.print_table(examples, indent: 2)
    end
  end
end

# rubocop:enable Metrics/MethodLength
