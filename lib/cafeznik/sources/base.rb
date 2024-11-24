module Cafeznik
  module Source
    class Base
      # TODO: change to `root: nil, repo: nil`
      def initialize(repo: nil, grep: nil)
        @repo = repo
        @grep = grep
      end

      def tree = raise NotImplementedError
      def expand_dir(_) = raise NotImplementedError
      def content(_) = raise NotImplementedError
      def dir?(_) = raise NotImplementedError

      def all_files = tree.reject(&method(:dir?))
    end
  end
end
