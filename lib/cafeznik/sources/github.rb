require_relative "base"
require "octokit"
require "base64"

module Cafeznik
  module Source
    class GitHub < Base
      def initialize(repo:, grep: nil, exclude: [])
        super
        @client = Octokit::Client.new(access_token:, auto_paginate: true)
        verify_connection!
        normalize_repo_name
      end

      def tree
        @_tree ||= begin
          all_paths = @grep ? grep_files(@grep) : full_tree
          all_paths.reject { |path| exclude?(path) }
        end
      rescue Octokit::Error => e
        Log.error "Error fetching GitHub tree: #{e.message}"
        []
      end

      def content(path)
        Base64.decode64 @client.contents(@repo, path:)[:content]
      rescue Octokit::Error => e
        Log.error "Error fetching GitHub content: #{e.message}"
        nil
      end

      def expand_dir(path) = tree.select { _1.start_with?(path) && !_1.end_with?("/") }
      def dir?(path) = path.end_with?("/")

      private

      def verify_connection!
        @client.repository(@repo)
      rescue Octokit::Error, Faraday::Error => e
        error_messages = {
          Faraday::ConnectionFailed => "You might be offline, or something is keeping you from connecting 🛜",
          Octokit::Unauthorized => "Unable to connect to GitHub. Please check your token / gh cli 🐙",
          Octokit::NotFound => "Repo not found. Can't help you 🪬"
        }
        Log.fatal error_messages[e.class] || e.message
      end

      def normalize_repo_name
        @repo = @repo[%r{github\.com[:/](.+?)(/?$)}, 1] || @repo.delete_prefix("/").delete_suffix("/")
      end

      def access_token = @_access_token ||=
                           ENV["GITHUB_TOKEN"] ||
                           fetch_token_via_gh ||
                           (Log.error("GitHub token not found. Please configure `gh` or set GITHUB_TOKEN in your environment.")
                            exit 1)

      def full_tree
        branch = @client.repository(@repo).default_branch
        # get all all paths and add a trailing slash for directories
        paths = @client.tree(@repo, branch, recursive: true).tree.map { "#{it.path}#{'/' if it.type == 'tree'}" }
        (["./"] + paths).sort
      end

      def fetch_token_via_gh
        Log.debug("Fetching GitHub token via GitHub CLI")
        Log.fatal "GitHub CLI not installed. Either install it or set GITHUB_TOKEN in your environment" unless ToolChecker.gh_available?
        TTY::Command.new(printer: :null).run("gh auth token").out.strip
      rescue TTY::Command::ExitError
        Log.warn("Failed to fetch GitHub token via GitHub CLI. Install GH and authenticate with `gh auth login`, or set GITHUB_TOKEN in your environment")
        nil
      end

      def grep_files(pattern)
        Log.debug "Searching for pattern '#{pattern}' within #{@repo}"
        results = @client.search_code("#{pattern} repo:#{@repo} in:file").items.map(&:path)
        Log.debug "Found #{results.size} files matching pattern '#{pattern}' in #{@repo}"
        results
      rescue Octokit::Error => e
        Log.error "Error during search for pattern '#{pattern}': #{e.message}"
        []
      end
    end
  end
end
