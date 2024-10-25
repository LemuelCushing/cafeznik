require_relative "base"

module Cafeznik
  module Source
    class Local < Base
      def tree = @_tree ||= ["./"] + Dir.glob("**/*").sort

      def all_files = tree.reject { |path| File.directory?(path) }

      # TODO: check if this doubles the slashes (//)
      def expand_dir(path) = Dir.glob("#{path.chomp('/')}/**/*").reject { |p| File.directory?(p) }

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
