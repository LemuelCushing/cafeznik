require_relative "base"
require "fast_ignore"

module Cafeznik
  module Source
    class Local < Base
      def tree
        @_tree ||= Dir.glob("**/*", File::FNM_DOTMATCH)
                      .select { |path| gitignore.allowed?(path, include_directories: true) }
                      .sort
      end

      def all_files = tree.reject { |path| File.directory?(path) }

      def expand_dir(path) = Dir.glob("#{path.chomp('/')}/**/*", File::FNM_DOTMATCH)
                                .reject { |p| File.directory?(p) || !gitignore.allowed?(p) }

      def dir?(path) = File.directory?(path)

      # TODO: rename to file_contents
      def content(path)
        File.read(path)
      rescue Errno::ENOENT
        Log.error "File not found: #{path}"
        nil
      end

      private

      def gitignore = FastIgnore.new
    end
  end
end
