require "open3"
require "json"
require_relative "base"

module Cafeznik
  module Source
    class Diff < Base
      def initialize(raw: false, repeat_file: nil, skip_context: 15)
        super()
        @raw = raw
        @repeat_file = repeat_file
        @skip_context = skip_context
      end

      def tree
        @tree ||= begin
          if @repeat_file
            load_repeat_file
          else
            build_file_list
          end
        end
      end

      private

      def load_repeat_file
        begin
          first_line = File.open(@repeat_file, &:readline).chomp
          @full_files = @files_to_output = JSON.parse(first_line)
        rescue => e
          Log.fatal "❌ Couldn’t read repeat list: #{e.message}"
        end
        @full_files
      end

      def build_file_list
        base = find_merge_base
        changed = git_diff_name_status(base)
        untracked = git_ls_files_others
        files = (changed + untracked).uniq
        exit 0 if files.empty?

        entries = build_entries(files)
        sort_entries(entries)
        @full_files = entries.map { |e| e[:path] }
        @files_with_timestamps = entries.map { |e| format_entry(e) }
      end

      def find_merge_base
        base, _ = Open3.capture2("git", "merge-base", "HEAD", "main")
        base.strip!
        unless base.match?(/\h{40}/)
          Log.fatal "❌ Couldn’t find merge-base with main"
        end
        base
      end

      def git_diff_name_status(base)
        stdout, _ = Open3.capture2("git", "diff", "--name-status", base)
        stdout.lines.grep(/^[AMR]/).map { |l| l.split("\t", 2).last.strip }
      end

      def git_ls_files_others
        stdout, _ = Open3.capture2("git", "ls-files", "--others", "--exclude-standard")
        stdout.lines.map(&:strip)
      end

      def build_entries(files)
        files.map do |file|
          raw_ct = Open3.capture2("git", "log", "-1", "--format=%ct", "--", file).first.strip
          commit_ts = raw_ct.empty? ? nil : raw_ct.to_i
          file_ts = File.mtime(file).to_i rescue 0
          changed = Open3.capture2("git", "diff", "--name-only", "--", file).first.strip.include?(file)

          {
            path: file,
            commit_ts: commit_ts,
            file_ts: file_ts,
            changed: changed,
            new_file: commit_ts.nil?
          }
        end
      end

      def sort_entries(entries)
        entries.sort_by! do |e|
          [
            e[:changed] ? 0 : 1,
            -(e[:commit_ts] || e[:file_ts]),
            -e[:file_ts]
          ]
        end
      end

      def format_entry(entry)
        commit_str = entry[:commit_ts] ? Time.at(entry[:commit_ts]).strftime("%m-%d %H:%M") : "—"
        file_str = Time.at(entry[:file_ts]).strftime("%m-%d %H:%M")
        marker = entry[:new_file] ? "✨ " : (entry[:changed] ? "⌽ " : "")
        "(C:#{commit_str} | U:#{file_str}) エ #{entry[:path]} #{marker}"
      end

      def content_with_diff(file)
        out = []
        # skip binaries
        return if file =~ /\.(png|jpe?g|gif|pdf|ico|woff2?|ttf|eot|svg|zip|tars?z|mp[34]|wav|docx?)$/i

        if @full_files.include?(file)
          # verbose tail to print header
          content, _ = Open3.capture2("tail", "-n", "+1", "-v", file)
          out << content unless content.strip.empty?
        else
          out << "==> #{file} <=="
          out << "[Full content skipped; showing diff with #{@skip_context} lines of context]"
        end

        unless @raw
          base = find_merge_base
          # diff with context
          diff_cmd = ["git", "diff", "-U#{@skip_context}", base, "--", file]
          diff_out, _ = Open3.capture2(*diff_cmd)
          # If this is a new file, truncate diff after the "new file mode" line
          if diff_out.lines.any? { |l| l.start_with?("new file mode") }
            mode_line = diff_out.lines.find { |l| l.start_with?("new file mode") }
            header_lines = diff_out.lines.take_while { |l| !l.start_with?("new file mode") }
            diff_out = (header_lines + [mode_line]).join
          end
          unless diff_out.strip.empty?
            out << "==> DIFF vs main (context: #{@skip_context}) <=="
            out << diff_out
          end
        end
        out.join("\n")
      end
    end
  end
end
