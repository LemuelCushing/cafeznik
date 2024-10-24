module Cafeznik
  module Source
    class Base
      def initialize(repo = nil) = @repo = repo
      def tree = raise NotImplementedError
      def all_files = raise NotImplementedError
      def expand_dir(_) = raise NotImplementedError
      def content(_) = raise NotImplementedError
    end
  end
end