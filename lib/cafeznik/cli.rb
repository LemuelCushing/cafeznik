require 'optparse'
require 'tty-command'
require 'octokit'
require 'clipboard'
require 'base64'

module Cafeznik
  class CLI
    class << self
      def start(argv)
        options = parse_options(argv)
        repo = options[:repo]

        unless repo
          puts "no repository provided. use -r or --repo to specify a github repository."
          exit 1
        end

        file_structure = fetch_file_tree_from_github(repo)
        if file_structure.empty?
          puts "no files or directories found in the repository."
          exit 1
        end

        selected_items = select_items(file_structure, options[:verbose])
        if selected_items.empty?
          puts "no items selected."
          exit 0
        end

        all_files = expand_selected_items(repo, selected_items, options[:verbose])
        copy_files_to_clipboard(repo, all_files, options[:no_header], options[:verbose])
      end

      private

      def parse_options(argv)
        options = { no_header: false, verbose: false }
        OptionParser.new do |opts|
          opts.banner = "usage: cafeznik [options]"

          opts.on("--no-header", "-nh", "use `cat` instead of `tail -n +1`") do
            options[:no_header] = true
          end

          opts.on("-r", "--repo REPO", "github repository (owner/repo format)") do |r|
            options[:repo] = r
          end

          opts.on("-v", "--verbose", "run in verbose mode, showing internal logs") do
            options[:verbose] = true
          end

          opts.on("-h", "--help", "show this help message") do
            puts opts
            exit
          end
        end.parse!(argv)
        options
      end

      def fetch_github_token = @github_token ||= 
        ENV['GITHUB_TOKEN'] || 
        fetch_token_via_gh || 
        (puts("github token not found. please configure `gh` or set GITHUB_TOKEN in your environment.") && exit(1))

      def fetch_token_via_gh
        cmd = TTY::Command.new(printer: verbose? ? :pretty : :null)
        result = cmd.run("gh auth token")
        result.out.strip
      rescue TTY::Command::ExitError
        nil
      end

      def fetch_file_tree_from_github(repo)
        client = Octokit::Client.new(access_token: fetch_github_token)
        contents = client.contents(repo)
        extract_paths(repo, contents)
      rescue Octokit::NotFound
        puts "repository not found: #{repo}" if verbose?
        exit 1
      end

      def extract_paths(repo, contents)
        contents.each_with_object([]) do |item, paths|
          paths << item[:path]
          if item[:type] == 'dir'
            dir_contents = Octokit.contents(repo, path: item[:path])
            paths.concat(extract_paths(repo, dir_contents))
          end
        end
      end

      def select_items(paths, verbose)
        cmd = TTY::Command.new(printer: verbose ? :pretty : :null)
        fzf_input = paths.map { |p| p.gsub("'", "'\\''") }.join("\n")
        result = cmd.run("echo '#{fzf_input}' | fzf --multi")
        result.out.strip.split("\n")
      rescue TTY::Command::ExitError
        []
      end

      def expand_selected_items(repo, selections, verbose)
        client = Octokit::Client.new(access_token: fetch_github_token)
        selections.each_with_object([]) do |selection, all_files|
          item = client.contents(repo, path: selection)
          if item.is_a?(Array)
            all_files.concat(extract_files(repo, item))
          elsif item[:type] == 'file'
            all_files << selection
          end
        rescue Octokit::NotFound
          puts "selected item not found: #{selection}" if verbose
        end.uniq
      end

      def extract_files(repo, contents)
        contents.each_with_object([]) do |item, files|
          if item[:type] == 'dir'
            dir_contents = Octokit.contents(repo, path: item[:path])
            files.concat(extract_files(repo, dir_contents))
          elsif item[:type] == 'file'
            files << item[:path]
          end
        end
      end

      def copy_files_to_clipboard(repo, files, no_header, verbose)
        client = Octokit::Client.new(access_token: fetch_github_token)
        contents = files.map do |file|
          file_content = client.contents(repo, path: file)[:content]
          decoded_content = Base64.decode64(file_content)
          header = "==> #{file} <==\n"
          body = no_header ? decoded_content : decoded_content.lines.drop(1).join
          header + body
        end.join("\n\n")
        Clipboard.copy(contents)
        puts "copied #{files.size} file(s) to clipboard"
      end

      def verbose? = @verbose ||= false
    end
  end
end
