FILE_STRUCTURE = {
  "README.md" => "# Test Project",
  "src" => {
    "main.rb" => "puts 'Hello, World!'",
    "other.rb" => "class Other; end",
    "with_helper.rb" => "include Helper",
    "lib" => {
      "helper.rb" => "module Helper; end",
      "nested" => {
        "deep.rb" => "# Deep nested file"
      }
    },
    "error.log" => "error info"
  },
  "docs" => {
    "latest" => "# Latest Documentation",
    "old_docs" => "# Old Documentation",
    "helper.md" => "Helper docs"
  },
  ".config" => {
    "settings.yml" => "setting: true"
  },
  ".hidden_dir" => {
    ".hidden_file" => "secret",
    "regular_file" => "visible"
  },
  "assets" => {
    "image.png" => "image content",
    "image.png.meta" => "image metadata",
    "document.pdf" => "document content"
  },
  "ignored" => {
    "secret.txt" => "ignored content"
  },
  "special" => {
    "with spaces.rb" => "# Spacey",
    "special!@#.rb" => "# Special!",
    "ut-fu_χ𓆑𒀭.rb" => "The deepest reaches of the ⌖ Unicode Ꙭ table 🜂"
  },
  "debug.log" => "debug info",
  ".gitignore" => "ignored/\n*.log"
}.freeze
