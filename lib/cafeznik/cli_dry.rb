require 'dry/cli'
require 'tty-command'
require 'octokit'
require 'clipboard'
require 'base64'
require 'logger'
require 'fileutils'

module Cafeznik
  module DryCLI
    module Commands
      extend Dry::CLI::Registry

      class Main < Dry::CLI::Command
        desc "Select files, copy to clipboard; use --repo for GitHub repository"

        option :repo, type: :string, desc: "GitHub repository (owner/repo format)"
        option :verbose, type: :boolean, default: false, desc: "Run in verbose mode"
        option :no_header, type: :boolean, default: false, desc: "Exclude headers from copied content"
        option :with_tree, type: :boolean, default: false, desc: "Include the tree structure in the content"

        def call(**options)
          log.info "Processing in #{repo ? 'GitHub' : 'local'} mode"

          if repo
            log.info "Fetching from GitHub repository: #{repo}"
            tree = github_tree(repo)
          else
            log.info "Fetching from local directory"
            tree = local_tree
          end

          selected = select_files(tree)
          copy_to_clipboard(selected, no_header, with_tree, tree)
        end

        private

        def github_tree(repo)
          @_github_tree ||= begin
            client = Octokit::Client.new(access_token: github_token)
            branch = client.repository(repo).default_branch
            tree = client.tree(repo, branch, recursive: true).tree

            files = tree.select { |item| item.type == 'blob' }.map(&:path)
            dirs = files.map { |file| File.dirname(file) }.uniq

            log.info "GitHub tree fetched with #{files.size} files and #{dirs.size} directories."
            build_file_tree(dirs, files)
          end
        end

        def local_tree
          @_local_tree ||= begin
            files = Dir.glob('**/*', File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
            dirs = files.map { |file| File.dirname(file) }.uniq

            log.info "Local tree fetched with #{files.size} files and #{dirs.size} directories."
            build_file_tree(dirs, files)
          end
        end

        def build_file_tree(dirs, files)
          (dirs + files).uniq.sort_by do |path|
            parts = path.split('/')
            [parts.count, path]
          end.prepend('./')
        end

        def github_token
          @_github_token ||= ENV['GITHUB_TOKEN'] || fetch_gh_token || (logger.error("GitHub token not found") && exit(1))
        end

        def fetch_gh_token
          token = TTY::Command.new.run("gh auth token").out.strip
          return unless token && !token.empty?

          log.info "GitHub token fetched via CLI."
          token
        end

        def select_files(tree)
          result = TTY::Command.new.run("echo \"#{tree.join("\n")}\" | fzf --multi").out.strip.split("\n")
          log.info "#{result.size} item(s) selected."

          result.flat_map do |item|
            directory?(item) ? files_in_directory(item) : item
          end.uniq
        end

        def files_in_directory(dir)
          tree[:files].select { |file| file.start_with?("#{dir}/") }
        end

        def copy_to_clipboard(selected_files, no_header, with_tree, tree)
          contents = selected_files.filter_map { |file| file_content(file, no_header) }
          contents.prepend(tree_representation(tree)) if with_tree

          warn_if_large(contents)
          Clipboard.copy(contents.join("\n\n"))
          log.info "Copied #{selected_files.size} file(s) to clipboard."
        end

        def file_content(file, no_header)
          content = File.read(file) rescue nil
          return unless content

          no_header ? content : content.prepend("==> #{file} <==\n")
        end

        def tree_representation(tree) = "==> File Tree <==\n#{tree.join("\n")}"

        def warn_if_large(contents)
          if contents.join("\n").lines.size > 10_000
            log.warn "Content exceeds 10,000 lines. Confirm to continue (y/N): "
            exit unless STDIN.gets.strip.downcase == 'y'
          end
        end

        def directory?(path) =  File.directory?(path) || path.end_with?('/')

        def log

binding.irb

          @_logger ||= Logger.new($stdout).tap do |log|
            log.level = verbose ? Logger::DEBUG : Logger::INFO
            log.formatter = proc { |severity, _, _, msg| "[#{severity}] #{msg}\n" }
          end
        end
      end
      register 'main', Main
    end
  end
end
