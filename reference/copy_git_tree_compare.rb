#!/usr/bin/env ruby
# frozen_string_literal: true

require "open3"
require "optparse"
require "json"

options = {
  select:       false,
  skip_context: 15,
  raw:          false,
  repeat_file:  nil
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"
  opts.on("-s", "--select", "Interactively select files (via fzf)") { options[:select] = true }
  opts.on("-a", "--select-all", "Interactively deselect files (via fzf)") { options[:select_all] = true }
  opts.on("-k N", "--skip-context N", Integer,
          "Context lines for skipped-file diffs (default: #{options[:skip_context]})") { |n| options[:skip_context] = n }
  opts.on("-r", "--raw", "Copy files without diffs") { options[:raw] = true }
  opts.on("-o", "--output FILE", "Output to a file instead of clipboard") { |file| options[:output_file] = file }
  opts.on("-R FILE", "--repeat FILE", "Refresh from a previous output's file list") do |file|
    options[:repeat_file] = file
  end
  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end.parse!

# 1. Find merge-base with main (needed even in --repeat mode)
base, _ = Open3.capture2("git", "merge-base", "HEAD", "main")
base.strip!
unless base.match?(/\h{40}/)
  warn "❌ Couldn’t find merge-base with main"
  exit 1
end

# If --repeat, load the file list and skip the git + fzf logic
if options[:repeat_file]
  begin
    first = File.open(options[:repeat_file], &:readline).chomp
    full_files = files = JSON.parse(first)
    options[:select] = options[:select_all] = false

    options[:output_file] ||= options[:repeat_file]

    files_to_output = full_files

  rescue => e
    warn "❌ Couldn’t read repeat list: #{e.message}"
    exit 1
  end
else
  # 2. Gather changed & untracked files
  changed = Open3.capture2("git", "diff", "--name-status", base).first.lines
                .grep(/^[AMR]/).map { |l| l.split("\t", 2).last.strip }
  untracked = Open3.capture2("git", "ls-files", "--others", "--exclude-standard").first.lines
                  .map(&:strip)

  files = (changed + untracked).uniq
  exit 0 if files.empty?


  # 1. build an array of entries with commit_ts, file_ts, and changed flag
  entries = files.map do |file|
    # last commit unix timestamp, or nil if never committed
    raw_ct  = Open3.capture2("git", "log", "-1", "--format=%ct", "--", file).first.strip
    commit_ts = raw_ct.empty? ? nil : raw_ct.to_i

    # filesystem mtime (unix timestamp), or 0 if the file is missing/err
    file_ts = File.mtime(file).to_i rescue 0

    # check if the file has uncommitted changes
    changed = Open3.capture2("git", "diff", "--name-only", "--", file).first.strip.include?(file)

    {
      path:      file,
      commit_ts: commit_ts,
      file_ts:   file_ts,
      changed:   changed,
      new_file:  commit_ts.nil? # Mark as new if never committed
    }
  end

  # 2. sort:
  #    - changed files first (changed? → 0, else 1)
  #    - then by commit_ts descending
  #    - then by file_ts descending
  entries.sort_by! do |e|
    [
      e[:changed] ? 0 : 1,
      -(e[:commit_ts] || e[:file_ts]), # Use file_ts for new files
      -e[:file_ts]
    ]
  end

  # 3. prepare display lines for fzf, and extract the real file list
  files_with_timestamps = entries.map do |e|
    # pretty-print timestamps (or “—” if none)
    commit_str = e[:commit_ts] ? Time.at(e[:commit_ts]).strftime("%m-%d %H:%M") : "—"
    file_str   = Time.at(e[:file_ts]).strftime("%m-%d %H:%M")

    # mark changed files with a ⌽ and new files with a ✨
    marker = e[:new_file] ? "✨ " : (e[:changed] ? "⌽ " : "")

    "(C:#{commit_str} | U:#{file_str}) エ #{e[:path]} #{marker}"
  end

  # Ensure `full_files` contains only file paths for file-related operations
  full_files = entries.map { |e| e[:path] }

  if options[:select] || options[:select_all]
    unless system("which fzf > /dev/null 2>&1")
      warn "❌ fzf not found; install fzf or drop --select"
      exit 1
    end

    args = ["fzf", "--multi", "--sync"]
    if options[:select_all]
      args.concat(["--bind", "start:last+select-all"])
    end
    selection, _ = Open3.capture2(
      *args,
      stdin_data: files_with_timestamps.join("\n")
    )
    # "(C:#{commit_str} | U:#{file_str}) エ #{e[:path]} #{marker}" (marker is optional - ⌽)
    full_files = selection.lines.map { |line| line[/エ (.+?) /, 1] }.compact.uniq
  end

  files_to_output = (options[:select] || options[:select_all] || options[:raw]) ? full_files : files
end

# 4. Build the output buffer
out = []

files_to_output.each do |file|
  # skip binaries
  next if file =~ /\.(png|jpe?g|gif|pdf|ico|woff2?|ttf|eot|svg|zip|tars?z|mp[34]|wav|docx?)$/i

  if full_files.include?(file)
    # verbose tail to print header
    content, _ = Open3.capture2("tail", "-n", "+1", "-v", file)
    out << content unless content.strip.empty?
  else
    out << "==> #{file} <=="
    out << "[Full content skipped; showing diff with #{options[:skip_context]} lines of context]"
  end

  unless options[:raw]
    # diff with context
    diff_cmd = ["git", "diff", "-U#{options[:skip_context]}", base, "--", file]
    diff_out, _ = Open3.capture2(*diff_cmd)
    # If this is a new file, truncate diff after the "new file mode" line
    if diff_out.lines.any? { |l| l.start_with?("new file mode") }
      mode_line = diff_out.lines.find { |l| l.start_with?("new file mode") }
      header_lines = diff_out.lines.take_while { |l| !l.start_with?("new file mode") }
      diff_out = (header_lines + [mode_line]).join
    end
    unless diff_out.strip.empty?
      out << "==> DIFF vs main (context: #{options[:skip_context]}) <=="
      out << diff_out
    end
  end

  out << ""  # blank line between files
end

buffer = out.join("\n")

if options[:output_file]
  list = JSON.generate(files_to_output)
  if files_to_output.empty?
    puts "⚠️ No files to output."
    exit 0
  end
  File.write(options[:output_file], "#{list}\n#{buffer}")
  puts "✅ Saved #{files_to_output.size} files#{options[:raw] ? "" : "(with diffs)"} to #{options[:output_file]}."
  exit 0
else
  clip_cmd = case RUBY_PLATFORM
  when /darwin/ then "pbcopy"
  when /linux/  then "xclip -selection clipboard"
  else
    warn "⚠️ Clipboard copy not supported on this OS."
    exit 1
  end

  IO.popen(clip_cmd, "w") { |io| io.write(buffer) }
  puts "✅ Copied #{files_to_output.size} files#{options[:raw] ? "" : "(with diffs)"} to clipboard."
end
