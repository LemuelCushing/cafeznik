#!/usr/bin/env ruby

require 'optparse'
require 'tty-command'
require 'octokit'
require 'clipboard'
require 'base64'
require 'logger'

module Cafeznik
  class CLI
    class << self
      def start(argv)
        @argv = argv

        initialize_logger

        raise ArgumentError, "No repository provided. Use -r or --repo to specify a GitHub repository." unless repo
        raise ArgumentError, "No files or directories found in the repository." if repo_tree.empty?

        selected_files = select_paths
        copy_files_to_clipboard(selected_files)
      end

      private

      def options = @_options ||= parse_options(@argv)
      def repo = options[:repo]
      def repo_tree = @_repo_tree ||= fetch_repo_tree 

      def initialize_logger
        @logger = Logger.new($stdout)
        @logger.level = options[:verbose] ? Logger::DEBUG : Logger::INFO
        @logger.formatter = proc do |severity, _datetime, _progname, msg|
          "[#{severity}] #{msg}\n"
        end
      end

      def logger = @logger

      def parse_options(argv)
        options = { no_header: false, verbose: false }
        OptionParser.new do |opts|
          opts.banner = "Usage: cafeznik [options]"
          opts.on("--no-header", "-nh", "Exclude headers from copied content") { options[:no_header] = true }
          opts.on("-r", "--repo REPO", "GitHub repository (owner/repo format)") { |r| options[:repo] = r }
          opts.on("-v", "--verbose", "Run in verbose mode") { options[:verbose] = true }
          opts.on("-h", "--help", "Show this help message") {
            puts opts
            exit
          }
        end.parse!(argv)
        options
      end

      def github_token = @_github_token ||=
        ENV['GITHUB_TOKEN'] ||
        fetch_token_via_gh ||
        (logger.error("GitHub token not found. Please configure `gh` or set GITHUB_TOKEN in your environment.") && exit(1))


      def fetch_token_via_gh
        cmd = TTY::Command.new(printer: :null)
        result = cmd.run("gh auth token")
        token = result.out.strip
        logger.debug("Fetched GitHub token via GitHub CLI.")
        token.empty? ? nil : token
      rescue TTY::Command::ExitError
        logger.warn("Failed to fetch GitHub token via GitHub CLI.")
        nil
      end

      def client =  @_client ||= Octokit::Client.new(
        access_token: github_token,
        auto_paginate: true
      )
      

      def fetch_repo_tree
        default_branch = client.repository(repo).default_branch
        tree = client.tree(repo, default_branch, recursive: true)
        files = tree.tree.select { |item| item.type == 'blob' }.map(&:path)
        directories = files.map { |path| File.dirname(path) }.uniq.reject { |dir| dir == '.' }
        all_paths = files + directories.map { |dir| "#{dir}/" }
        all_paths.sort
      rescue Octokit::NotFound
        logger.error("Repository not found: #{@repo}")
        puts "Repository not found: #{@repo}"
        exit 1
      rescue Octokit::Error => e
        logger.error("Error fetching file tree: #{e.message}")
        puts "Error fetching file tree: #{e.message}"
        exit 1
      end

      def select_paths
        logger.debug("Initiating item selection with fzf.")
        cmd = TTY::Command.new(printer: options[:verbose] ? :pretty : :null)
        fzf_input = repo_tree.map { |p| p.gsub("'", "\\\\'") }.join("\n")
        result = cmd.run("echo \"#{fzf_input}\" | fzf --multi")
        selected_paths = result.out.strip.split("\n")
        logger.info("User selected_paths #{selected_paths.size} item(s).")
        expand_selected_paths(selected_paths)
      rescue TTY::Command::ExitError
        logger.info("fzf exited without selecting items.")
        exit 0
      rescue StandardError => e
        raise StandardError, "Error selecting items: #{e.message}"
      end

      def expand_selected_paths(selected_paths)
        selected_paths.each_with_object([]) do |selection, selected_files|
          if directory?(selection)
            dir_path = selection.chomp('/')
            matched_files = repo_tree.select { |path| path.start_with?("#{dir_path}/") && !path.end_with?('/') }
            selected_files.concat(matched_files)
            logger.debug("Expanded directory #{dir_path} to include #{matched_files.size} files.")
          else
            selected_files << selection
          end
        end.uniq
      end

      def copy_files_to_clipboard(files)
        contents = files.map do |file|
          content = fetch_file_content(file)
          next unless content

          content.prepend( "==> #{file} <==\n") unless options[:no_header]
          content
        end.compact.join("\n\n")

        Clipboard.copy(contents)
        logger.info("Copied #{files.size} file(s) to clipboard.")
        puts "Copied #{files.size} file(s) to clipboard."
      rescue Octokit::Error => e
        logger.error("Error copying files to clipboard: #{e.message}")
        puts "Error copying files to clipboard: #{e.message}"
        exit 1
      end

      def fetch_file_content(path)
        content = client.contents(repo, path:)[:content]
        Base64.decode64(content)
      rescue Octokit::Error => e
        logger.error("Error fetching content for #{path}: #{e.message}")
        nil
      end

      def directory?(selection) = selection.end_with?('/')
    end
  end
end
