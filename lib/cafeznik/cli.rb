require 'optparse'
require 'tty-command'
require 'octokit'
require 'clipboard'
require 'base64'

module Cafeznik
  class CLI
    def self.start(argv)
      options = parse_options(argv)
      repo = options[:repo]

      if repo.nil?
        puts "No repository provided. Use -r or --repo to specify a GitHub repository."
        exit 1
      end

      # Fetch repository file structure
      files = fetch_files_from_github(repo)

      if files.empty?
        puts "No files found in the repository."
        exit 1
      end

      # Use fzf to select files
      selected_files = select_files(files)

      if selected_files.empty?
        puts "No files selected."
        exit 0
      end

      # Copy file contents to clipboard
      copy_files_to_clipboard(repo, selected_files, options[:use_cat])
    end

    # Parse options like --repo, --no-header
    def self.parse_options(argv)
      options = { use_cat: false }
      OptionParser.new do |opts|
        opts.banner = "Usage: cafeznik [--no-header|-nh] <files>"

        opts.on("--no-header", "-nh", "Use `cat` instead of `tail -n +1`") do
          options[:use_cat] = true
        end

        opts.on("-r", "--repo REPO", "GitHub repository (owner/repo format)") do |r|
          options[:repo] = r
        end

        opts.on("-h", "--help", "Show this help message") do
          puts opts
          exit
        end
      end.parse!(argv)
      options
    end

    # Fetch GitHub token from gh or git config
    def self.fetch_github_token
      token = nil

      # First, try to get the token via `gh`
      begin
        cmd = TTY::Command.new
        result = cmd.run("gh auth status --show-token")
        token = result.out.match(/Token: (\S+)/)[1] rescue nil
      rescue TTY::Command::ExitError
        # If `gh` is not installed or no token found, continue
      end

      # Fallback: Check for the token in environment variables
      token ||= ENV['GITHUB_TOKEN']

      unless token
        puts "GitHub token not found. Please configure `gh` or set GITHUB_TOKEN in your environment."
        exit 1
      end

      token
    end

    # Fetch files from the GitHub repository
    def self.fetch_files_from_github(repo)
      client = Octokit::Client.new(access_token: fetch_github_token)
      begin
        contents = client.contents(repo)
        files = extract_files(contents)
      rescue Octokit::NotFound
        puts "Repository not found: #{repo}"
        exit 1
      end
      files
    end

    # Recursively extract files from GitHub contents API
    def self.extract_files(contents, path = "")
      files = []
      contents.each do |item|
        if item[:type] == 'dir'
          dir_contents = Octokit.contents(item[:repository][:full_name], path: item[:path])
          files.concat(extract_files(dir_contents, item[:path]))
        elsif item[:type] == 'file'
          files << item[:path]
        end
      end
      files
    end

    # Use fzf for file selection
    def self.select_files(files)
      cmd = TTY::Command.new
      result = cmd.run("echo '#{files.join("\n")}' | fzf --multi")
      result.out.strip.split("\n")
    rescue TTY::Command::ExitError
      [] # Handle user pressing ESC in fzf
    end

    # Copy selected files' content to clipboard using cat or tail -n +1
    def self.copy_files_to_clipboard(repo, selected_files, use_cat)
      client = Octokit::Client.new(access_token: fetch_github_token)

      contents = selected_files.map do |file|
        file_content = client.contents(repo, path: file)[:content]
        decoded_content = Base64.decode64(file_content)

        if use_cat
          decoded_content
        else
          `echo "#{decoded_content}" | tail -n +1`
        end
      end.join("\n")

      Clipboard.copy(contents)
      puts "Copied #{selected_files.size} file(s) to clipboard."
    end
  end
end
