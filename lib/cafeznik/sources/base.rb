module Cafeznik
  module Source
    class Base
      # TODO: change to `root: nil, repo: nil`
      def initialize(repo: nil, grep: nil, exclude: [])
        @repo = repo
        @grep = grep
        @exclude = exclude
      end

      def tree = raise NotImplementedError
      def expand_dir(_) = raise NotImplementedError
      def content(_) = raise NotImplementedError
      def dir?(_) = raise NotImplementedError

      def exclude?(path)
        Log.debug "Checking exclusion for #{path} against #{@exclude}"
        excluded = @exclude.any? { |pattern| File.fnmatch?(pattern, path, File::FNM_PATHNAME) }
        Log.debug "Exclusion result: #{excluded}"
        excluded
      end

      def all_files = tree.reject(&method(:dir?))
    end
  end
end
