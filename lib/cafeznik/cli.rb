#!/usr/bin/env ruby

require 'thor'
require 'tty-command'
require 'octokit'
require 'clipboard'
require 'base64'
require 'logger'
require 'fileutils'

module Cafeznik
  class CLI < Thor
    class_option :verbose, type: :boolean, default: false, desc: "Run in verbose mode"
    class_option :no_header, type: :boolean, default: false, desc: "Exclude headers from copied content"
    class_option :with_tree, type: :boolean, default: false, desc: "Include the tree structure in the content"
    
    desc "default", "Default task: Select files, copy to clipboard; use --repo for GitHub repository"
    method_option :repo, type: :string, aliases: '-r', desc: "GitHub repository (owner/repo format)"
    
    default_task :default

    MAX_FILES = 20
    MAX_LINES = 10_000

    def default
      log.info "#{repo ? 'GitHub' : 'local'} mode"

      selected = select_files
      copy_files_to_clipboard(selected)
    end

    private

    # Accessors for options
    def repo = options[:repo]
    def verbose? = options[:verbose]
    def no_header? = options[:no_header]
    def with_tree? = options[:with_tree]

    def tree = @_tree ||= repo ? github_tree : local_tree

    def log
      @_logger ||= Logger.new($stdout).tap do |log|
        log.level = verbose? ? Logger::DEBUG : Logger::INFO
        log.formatter = proc { |severity, _, _, msg| "[#{severity}] #{msg}\n" }
      end
    end

    def github_token
      @_github_token ||= ENV['GITHUB_TOKEN'] || gh_token || (log.error("GitHub token not found") && exit(1))
    end

    def gh_token
      cmd = TTY::Command.new(printer: :null)
      result = cmd.run("gh auth token")
      token = result.out.strip
      log.info("Fetched GitHub token via GitHub CLI.")
      token.empty? ? nil : token
    rescue TTY::Command::ExitError
      log.warn("Failed to fetch GitHub token via GitHub CLI.")
      nil
    end

    def client = @_client ||= Octokit::Client.new(access_token: github_token, auto_paginate: true)

    def github_tree
      default_branch = client.repository(repo).default_branch
      tree = client.tree(repo, default_branch, recursive: true).tree

      files = tree.select { _1.type == 'blob' }.map(&:path)
      directories = files.map { File.dirname(_1) + "/" }

      (["./"] + files + directories).uniq.sort
    rescue Octokit::NotFound
      log.error("Repository not found: #{repo}")
      exit 1
    rescue Octokit::Error => e
      log.error("Error fetching file tree: #{e.message}")
      exit 1
    end

    def local_tree
      files = Dir.glob('**/*', File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
      directories = files.map { File.dirname(_1) + "/" }

      (["./"] + files + directories).uniq.sort
    end

    def select_files
      log.debug("Initiating file selection with fzf.")
      cmd = TTY::Command.new(printer: verbose? ? :pretty : :null)
      fzf_input = tree.join("\n")
      result = cmd.run("echo \"#{fzf_input}\" | fzf --multi")
      paths = result.out.strip.split("\n")
      log.info("User selected #{paths.size} item(s).")

      selected_files = paths.flat_map do |item|
        if item == "./"
          tree.reject(&method(:directory?))
        else
          directory?(item) ? files_in_directory(item.chomp('/')) : item
        end
      end.uniq

      log.info("Resolved to #{selected_files.size} file(s).")
      if selected_files.size > MAX_FILES
        log.warn("Warning: You selected more than #{MAX_FILES} files. Continue? (y/N)")
        exit 0 unless STDIN.gets.strip.downcase == 'y'
      end
      selected_files
    rescue TTY::Command::ExitError
      log.info("No items selected. Exiting.")
      exit 0
    end

    def files_in_directory(dir_path)
      tree.select { _1.start_with?("#{dir_path}/") }.reject(&method(:directory?))
    end

    def directory?(path) = path.end_with?('/')

    def copy_files_to_clipboard(selected_files)
      contents = selected_files.filter_map do |file|
        content = fetch_file_content(file)
        next unless content

        content.prepend("==> #{file} <==\n") unless no_header?
        content
      end.join("\n\n")

      contents.prepend("==> File Tree <==\n #{tree.join("\n")}\n\n") if with_tree?

      if contents.lines.size > MAX_LINES
        puts "Warning: The total content exceeds #{MAX_LINES} lines. Continue? (y/N)"
        exit 0 unless STDIN.gets.strip.downcase == 'y'
      end

      Clipboard.copy(contents)
      log.info("Copied #{selected_files.size} file(s) to clipboard - #{contents.lines.size} line(s).")
    end

    def fetch_file_content(path)
      content = client.contents(repo, path: path)[:content]
      Base64.decode64(content)
    rescue Octokit::Error => e
      log.error("Error fetching content for #{path}: #{e.message}")
      nil
    end
  end
end
