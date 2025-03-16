module Cafeznik
  module Help
    SECTION_CONFIGS = [
      {
        header: "Usage",
        color: :yellow,
        content: <<~USAGE
          cafeznik [OPTIONS]

          The default behavior (local mode) is invoked when no subcommand is given.
          To use GitHub mode, specify a repository with the --repo option.
        USAGE
      },
      {
        header: "Modes",
        color: :blue,
        content: <<~MODES
          Local Mode (default):
            - Copies files from your local file system.
          GitHub Mode:
            - Copies files from a GitHub repository (specify with --repo owner/repo).
        MODES
      },
      {
        header: "Options",
        color: :cyan,
        content: <<~OPTIONS
          --repo, -r       Specify a GitHub repository (owner/repo format)
          --grep, -g       Filter files: only include those containing a specific pattern
          --exclude        Exclude files/folders matching given glob patterns
          --with_tree, -t  Include the file tree structure in the output
          --no_header      Exclude file headers from the copied content
          --version, -v    Display version information
          --verbose        Enable verbose logging (detailed output)
          help             Display this help message
        OPTIONS
      },
      {
        header: "Examples",
        color: :green,
        content: <<~EXAMPLES
          cafeznik
            # Runs in local mode, processing all files in the current directory.
          cafeznik --repo owner/repo
            # Runs in GitHub mode using the specified repository.
          cafeznik --no_header --with_tree
            # Excludes file headers and includes the file tree in the output.
          cafeznik --grep "pattern"
            # Only includes files containing "pattern".
        EXAMPLES
      }
    ].freeze

    def self.display(cli)
      display_banner(cli)
      cli.say "\n"
      SECTION_CONFIGS.each do |section|
        display_section(cli, section[:header], section[:content], section[:color])
        cli.say "\n"
      end
    end

    def self.display_banner(cli)
      # Preserve your existing banner.
      version = Cafeznik::VERSION
      banner = <<~BANNER
        ╔◤ CΛFΞΖПIK v#{version} ◢═══════════╗
        ║─┳─ interactive ║ code2pilfer ║#{'	'}
        ╚═╂══════════════╩══════ꙮ══════╝
      BANNER
      cli.say banner, :green
    end

    def self.display_section(cli, header, content, color)
      # Display header in bold with an underline, then the section content.
      cli.say header, color
      cli.say "-" * header.length, color
      cli.say content, color
    end
  end
end
