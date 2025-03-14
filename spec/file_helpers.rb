require "fileutils"
require_relative "fixtures/file_structure"

GitHubEntry = Struct.new(:path, :type)

module FileHelpers
  def create_local_file_structure(structure = FILE_STRUCTURE, base_path = ".")
    structure.each do |name, content|
      path = File.join(base_path, name)
      if content.is_a?(Hash)
        FileUtils.mkdir_p(path)
        create_local_file_structure(content, path)
      else
        File.write(path, content)
      end
    end
  end

  def create_github_tree_entries(structure = FILE_STRUCTURE, exclude_patterns = [])
    structure.flat_map do |name, content|
      case content
      when String
        should_exclude = exclude_patterns.any? do |pattern|
          if pattern.include?(File::SEPARATOR) || pattern.include?("/")
            File.fnmatch?(pattern, name, File::FNM_PATHNAME)
          else
            File.fnmatch?(pattern, File.basename(name))
          end
        end
        should_exclude ? [] : [GitHubEntry.new(name, "blob")]
      when Hash
        dir_entries = [GitHubEntry.new(name, "tree")]
        nested_entries = create_github_tree_entries(content, exclude_patterns).map do |entry|
          GitHubEntry.new("#{name}/#{entry.path}", entry.type)
        end
        dir_entries + nested_entries
      end
    end
  end

  def format_github_tree(entries)
    formatted = entries.map do |entry|
      entry.type == "tree" ? "#{entry.path}/" : entry.path
    end

    ["./"] + formatted.sort
  end

  def expected_github_tree(structure = FILE_STRUCTURE, exclude_patterns = [])
    # Make sure we're using the same exclusion logic as the Source::Base class
    binary_excludes = Cafeznik::Source::Base::BINARY_EXCLUDES
    all_exclusions = Array(exclude_patterns) + binary_excludes

    entries = create_github_tree_entries(structure, all_exclusions)
    format_github_tree(entries)
  end
end
