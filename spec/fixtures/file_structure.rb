FILE_STRUCTURE = {
  "README.md" => "# Test Project",
  "src" => {
    "main.rb" => "puts 'Hello, World!'",
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
    "old_docs" => "# Old Documentation"
  },
  ".config" => {
    "settings.yml" => "setting: true"
  },
  ".hidden_dir" => {
    ".hidden_file" => "secret",
    "regular_file" => "visible"
  },
  # "assets" => {
  #   "image.png" => "replace with binary content"
  # },
  "ignored" => {
    "secret.txt" => "ignored content"
  },
  "debug.log" => "debug info",
  ".gitignore" => "ignored/\n*.log"
}.freeze
