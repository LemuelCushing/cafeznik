require "fileutils"
require "base64"

module Cafeznik
  module TestFixtures
    module_function

    ROOT = File.expand_path("../fixtures/copy", __dir__)

    # File content generators
    def big_content = "x" * 1_000_000
    def utf16_content = "Hello World".encode("UTF-16LE")
    def binary_content = Base64.decode64("R0lGODlhAQABAIAAAAUEBAAAACwAAAAAAQABAAACAkQBADs=") # 1x1 GIF
    def mixed_endings = "line1\r\nline2\nline3\r\nline4\n"

    def create
      clean_root
      create_structure
      create_symlinks
    end

    def clean_root
      FileUtils.rm_rf(ROOT)
      FileUtils.mkdir_p(ROOT)
    end

    def create_structure
      structure.each do |path, content|
        full_path = File.join(ROOT, path)
        if path.end_with?("/")
          FileUtils.mkdir_p(full_path)
        else
          FileUtils.mkdir_p(File.dirname(full_path))
          File.write(full_path, content || "Content of #{path}")
        end
      end
    end

    def create_symlinks
      symlinks.each do |link, target|
        full_link = File.join(ROOT, link)
        FileUtils.ln_s(target, full_link)
      end
    end

    def structure
      [
        root_files,
        basic_folders,
        nested_structures,
        special_cases,
        content_cases,
        path_cases
      ].reduce({}, :merge)
    end

    def root_files
      {
        ".gitignore" => "*.log\nignored_folder/",
        ".hidden_root_file" => nil,
        "regular_file.txt" => nil,
        "with space.txt" => nil,
        "with_special!@#.txt" => nil,
        "with_unicode_éñ.txt" => nil,
        "very_long_file_name_that_goes_on_and_on_and_on.txt" => nil
      }
    end

    def basic_folders
      {
        # Folder1
        "folder1/" => nil,
        "folder1/.hidden_subfolder_file" => nil,
        "folder1/file.txt" => nil,
        "folder1/ignored_file.log" => nil,

        # Folder2
        "folder2/" => nil,
        "folder2/file.txt" => nil,
        "folder2/unique.txt" => nil,

        # Empty folder
        "empty_folder/" => nil
      }
    end

    def nested_structures
      {
        # Nested structure
        "nested/" => nil,
        "nested/subfolder/" => nil,
        "nested/subfolder/deep_file.txt" => nil,
        "nested/subfolder/empty_folder/" => nil,
        "nested/another_file.txt" => nil,

        # Ignored folder
        "ignored_folder/" => nil,
        "ignored_folder/should_not_appear.txt" => nil,

        # Deep nesting
        "deep_nest/" => nil,
        "deep_nest/level1/" => nil,
        "deep_nest/level1/level2/" => nil,
        "deep_nest/level1/level2/level3/" => nil,
        "deep_nest/level1/level2/level3/level4/" => nil,
        "deep_nest/level1/level2/level3/level4/deep_file.txt" => nil
      }
    end

    def special_cases
      {
        # Special characters
        "special_chars/" => nil,
        "special_chars/αβγδε.txt" => nil,
        "special_chars/with!@#$%^&.txt" => nil,
        "special_chars/お早うございます.txt" => nil,

        # Symlinks folder
        "symlinks/" => nil
      }
    end

    def content_cases
      {
        "content_cases/" => nil,
        "content_cases/empty.txt" => "",
        "content_cases/big_file.txt" => big_content,
        "content_cases/utf16_file.txt" => utf16_content,
        "content_cases/binary.bin" => binary_content,
        "content_cases/mixed_endings.txt" => mixed_endings
      }
    end

    def path_cases
      {
        "dots.in.path/" => nil,
        "dots.in.path/file.txt" => nil,
        "no_extension" => nil,
        "multiple.dots.in.file.name.txt" => nil,
        "very.long.folder.name.that.goes.on.and.on.and.on/" => nil,
        "very.long.folder.name.that.goes.on.and.on.and.on/file.txt" => nil
      }
    end

    def symlinks
      {
        "symlinks/link_to_file.txt" => "../regular_file.txt",
        "symlinks/link_to_folder" => "../folder1",
        "symlinks/link_to_sibling" => "./another_link",
        "symlinks/link_to_deep" => "../deep_nest/level1"
      }
    end

    def clean
      FileUtils.rm_rf(ROOT) if Dir.exist?(ROOT)
    end
  end
end
