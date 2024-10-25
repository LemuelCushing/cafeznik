require_relative "base"
require "fast_ignore"

module Cafeznik
  module Source
    class Local < Base
      def tree
        @_tree ||= begin
          paths = Dir.glob("**/*", File::FNM_DOTMATCH)
          ignore = FastIgnore.new
          paths.select { |path| ignore.allowed?(path, include_directories: true) }.sort
        end
      end

      def all_files = tree.reject { |path| File.directory?(path) }

      # TODO: check if this doubles the slashes (//)
      def expand_dir(path)
        Dir.glob("#{path.chomp('/')}/**/*", File::FNM_DOTMATCH).reject { |p| File.directory?(p) }
      end

      def dir?(path) = File.directory?(path)

      def content(path)
        File.read(path)
      rescue Errno::ENOENT
        Log.error "File not found: #{path}"
        nil
      end
    end
  end
end
