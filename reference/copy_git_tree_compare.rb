#!/usr/bin/env ruby

require 'open3'

# Find the base commit (merge base with main)
base_commit = `git merge-base HEAD main`.strip
exit 1 if base_commit.empty?

# Get changed files (Added, Modified, Renamed)
files = `git diff --name-status #{base_commit}`.lines
            .grep(/^[AMR]/)
            .map { |line| line.split("\t", 2).last.strip }
            .reject(&:empty?)

exit 0 if files.empty?

# Prepare output buffer
output = []

# Append content of each file with headers (tail-like behavior)
files.each do |file|
  output << "==> #{file} <==\n"
  file_content, _ = Open3.capture2("tail", "-n", "+1", file)
  output << file_content unless file_content.strip.empty?

  # Append git diff vis-a-vis main
  diff_output, _ = Open3.capture2("git", "diff", base_commit, "--", file)
  unless diff_output.strip.empty?
    output << "\n==> DIFF vs main <==\n"
    output << diff_output
  end

  output << "\n" # Add spacing between files
end

# Join everything
final_output = output.join("\n")

# Copy to clipboard (macOS: pbcopy, Linux: xclip/xsel)
clipboard_cmd = case RUBY_PLATFORM
                when /darwin/ then "pbcopy"
                when /linux/  then "xclip -selection clipboard"
                else
                  warn "Clipboard copying not supported on this OS."
                  exit 1
                end

IO.popen(clipboard_cmd, "w") { |io| io.write(final_output) }

puts "Copied #{files.size} files (and their diffs) to clipboard."
