require "fileutils"
require "base64"

module Cafeznik
  module Testing
    module Filesystem
      extend self

      def with_test_fs
        require "fakefs/safe"
        FakeFS.activate!
        create_file_structure
        yield if block_given?
      ensure
        FakeFS.deactivate!
      end

      private

      def create_file_structure
        create_directories
        create_files
        create_symlinks
        write_gitignore
      end

      def create_directories
        DIRECTORY_STRUCTURE.each do |dir|
          FileUtils.mkdir_p(dir)
        end
      end

      def create_files
        FILE_CONTENTS.each do |path, content|
          FileUtils.mkdir_p(File.dirname(path))
          write_with_encoding(path, content)
        end
      end

      def write_with_encoding(path, content)
        case path
        when /binary\.dat$/
          File.binwrite(path, content)
        when /utf16\.txt$/
          File.write(path, content, encoding: Encoding::UTF_16LE)
        else
          File.write(path, content || "Content of #{path}")
        end
      end

      def create_symlinks
        SYMLINKS.each do |link, target|
          FileUtils.mkdir_p(File.dirname(link))
          FileUtils.rm_f(link)
          FileUtils.ln_s(target, link)
        end
      end

      def write_gitignore
        # Write gitignore first so FastIgnore can initialize with it
        File.write(".gitignore", GITIGNORE_CONTENT)
        FileUtils.touch(".gitignore") # Ensure file time is set
      end

      DIRECTORY_STRUCTURE = [
        "src",
        "src/lib",
        "src/lib/nested",
        "test",
        "docs",
        "docs/api",
        "build",
        "temp",
        ".git",
        ".config"
      ].freeze

      FILE_CONTENTS = {
        # Regular files
        "README.md" => "# Test Project\nThis is a test project.",
        "docs/api/index.html" => "<html>API docs</html>",
        "src/main.rb" => "puts 'Hello, World!'",
        "src/lib/helper.rb" => "module Helper; end",
        "src/lib/nested/deep.rb" => "# Deep nested file",

        # Hidden files
        ".env" => "SECRET_KEY=test123",
        ".config/settings.yml" => "environment: test",

        # Special content files
        "test/binary.dat" => Base64.decode64("R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs="),
        "test/utf16.txt" => "Hello World".encode("UTF-16LE"),
        "test/mixed_endings.txt" => "line1\r\nline2\nline3\r\nline4\n",

        # Files with special names
        "src/with spaces.rb" => "# File with spaces",
        "src/special!@#.rb" => "# Special characters",
        "src/utf8_χξς.rb" => "# UTF-8 filename",

        # Build artifacts
        "build/main.o" => "\x7FELF...",
        "build/.build_timestamp" => Time.now.to_s
      }.freeze

      SYMLINKS = {
        "docs/latest" => "api",
        "src/lib/alias.rb" => "helper.rb",
        "build/current" => "../src"
      }.freeze

      GITIGNORE_CONTENT = <<~GITIGNORE
        .env
        build/
        temp/
        *.log
        .DS_Store
      GITIGNORE
    end

    module Helper
      def with_test_fs(&)
        Filesystem.setup(&)
      end
    end
  end
end
