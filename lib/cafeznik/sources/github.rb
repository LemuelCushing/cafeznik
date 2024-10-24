require "octokit"
require "base64"
require_relative "base"
require_relative "../log"

module Cafeznik
  module Source
    class GitHub < Base
      def initialize(repo)
        super
        @repo = repo
        @client = Octokit::Client.new(access_token: ENV["GITHUB_TOKEN"], auto_paginate: true)
        # TODO: extract to client and get token from GH
      end

      def tree
        @_tree ||= begin
          branch = @client.repository(@repo).default_branch
          files = @client.tree(@repo, branch, recursive: true).tree
          paths = files.filter_map { _1.path if _1.type == "blob" }
          directories = paths.map { "#{File.dirname(_1)}/" }
          (["./"] + paths + directories).uniq.sort # TODO: sort properly
        rescue Octokit::Error => e
          Log.error "Error fetching GitHub tree: #{e.message}"
          nil
        end
      end

      def all_files = tree.reject { |path| path.end_with?("/") }

      def expand_dir(path) = tree.select { _1.start_with?(path) && !_1.end_with?("/") }

      def content(path)
        Base64.decode64 @client.contents(@repo, path:)[:content]
      rescue Octokit::Error => e
        Log.error "Error fetching GitHub content: #{e.message}"
        nil
      end
    end
  end
end
