#!/usr/bin/env ruby

require 'slop'
require 'tty-command'
require 'octokit'
require 'clipboard'
require 'base64'
require 'fileutils'
require 'tempfile'
require 'logger'

module Cafeznik
  class CLI
    MAX_LINES = 10_000
    MAX_FILES = 20
    class << self
      def start(argv)
        @argv = argv

        logger.error("No repository provided. Use -r or --repo to specify a GitHub repository.") && exit(1) unless repo
        logger.error("No files or directories found in the repository.") && exit(1) if repo_tree.empty?

        select_files
        copy_files_to_clipboard
      end

      private

      def options = @_options ||= parse_options(@argv)
      def repo = options[:repo]
      def repo_tree = @_repo_tree ||= fetch_repo_tree
      def selected_files = @selected_files ||= []

      def logger
        @_logger ||= Logger.new($stdout).tap do |log|
          log.level = options[:verbose] ? Logger::DEBUG : Logger::INFO
          log.formatter = proc { |severity, _, _, msg| "[#{severity}] #{msg}\n" }
        end
      end

      def parse_options(argv)
        Slop.parse(argv) do |o|
          o.banner = "Usage: cafeznik [options]"
          o.string '-r', '--repo', 'GitHub repository (owner/repo format)'
          o.bool '-nh', '--no-header', 'Exclude headers from copied content'
          o.bool '-tr', '--with-tree', 'Include the tree structure in the content'
          o.bool '-v', '--verbose', 'Run in verbose mode'
          o.on '-h', '--help' do
            puts o
            exit
          end
        end
      end

      def github_token = @_github_token ||=
        ENV['GITHUB_TOKEN'] ||
        fetch_token_via_gh ||
        (logger.error("GitHub token not found. Please configure `gh` or set GITHUB_TOKEN in your environment."); exit 1)

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

      def client = @_client ||= Octokit::Client.new(
        access_token: github_token,
        auto_paginate: true
      )

      def fetch_repo_tree
        default_branch = client.repository(repo).default_branch
        tree = client.tree(repo, default_branch, recursive: true).tree

        files = tree.select { _1.type == 'blob' }.map(&:path)
        directories = files.map { File.dirname(_1) + "/" }

        (["./"] + files + directories).uniq.sort
      rescue Octokit::NotFound
        logger.error("Repository not found: #{repo}")
        puts "Repository not found: #{repo}"
        exit 1
      rescue Octokit::Error => e
        logger.error("Error fetching file tree: #{e.message}")
        puts "Error fetching file tree: #{e.message}"
        exit 1
      end

      def select_files
        logger.debug("Initiating file selection with fzf.")
        cmd = TTY::Command.new(printer: options[:verbose] ? :pretty : :null)
        fzf_input = repo_tree.join("\n")
        result = cmd.run("echo \"#{fzf_input}\" | fzf --multi")
        paths = result.out.strip.split("\n")
        logger.info("User selected #{paths.size} item(s).")

        @selected_files = paths.flat_map do |item|
          if item == "./"
            repo_tree.reject(&method(:directory?))
          else
            directory?(item) ? files_in_directory(item.chomp('/')) : item
          end
        end.uniq

        logger.info("Resolved to #{@selected_files.size} file(s).")
        if @selected_files.size > MAX_FILES
          logger.warn("Warning: You selected more than #{MAX_FILES} files. Are you sure you want to continue? (y/N)")
          exit 0 unless STDIN.gets.strip.downcase == 'y'
        end
      rescue TTY::Command::ExitError
        logger.info("No items selected. Exiting.")
        exit 0
      rescue Errno::ENOENT => e
        logger.error("Command not found: #{e.message}")
        puts "Error: fzf command not found. Please install fzf to use this application."
        exit 1
      rescue StandardError => e
        raise "Error selecting files: #{e.message}"
      end

      def files_in_directory(dir_path)
        matched_files = repo_tree.select { _1.start_with?("#{dir_path}/") }.reject(&method(:directory?))
        logger.debug("Expanded directory #{dir_path} to include #{matched_files.size} files.")
        matched_files
      end

      def directory?(path) = path.end_with?('/')

      def copy_files_to_clipboard
        contents = selected_files.filter_map do |file|
          content = fetch_file_content(file)
          next unless content

          content.prepend("==> #{file} <==\n") unless options[:no_header]
          content
        end.join("\n\n")

        contents.prepend("==> File Tree <==\n #{repo_tree.join("\n")}\n\n") if options[:with_tree]

        if contents.lines.size > MAX_LINES
          puts "Warning: The total content exceeds #{MAX_LINES} lines. Are you sure you want to continue? (y/N)"
          exit 0 unless STDIN.gets.strip.downcase == 'y'
        end

        Clipboard.copy(contents)
        logger.info("Copied #{selected_files.size} file(s) to clipboard - #{contents.lines.size} line(s).")
      rescue Octokit::Error => e
        logger.error("Error copying files to clipboard: #{e.message}")
        exit 1
      end

      def fetch_file_content(path)
        content = client.contents(repo, path: path)[:content]
        Base64.decode64(content)
      rescue Octokit::Error => e
        logger.error("Error fetching content for #{path}: #{e.message}")
        nil
      end
    end
  end
end
