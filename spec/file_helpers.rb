require "fileutils"
require_relative "fixtures/file_structure"

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

  def mock_github_tree(structure = FILE_STRUCTURE)
    structure.flat_map do |name, content|
      case content
      when String
        [{ path: name, type: "blob" }]
      when Hash
        dir_entry = { path: "#{name}/", type: "tree" }
        sub_entries = mock_github_tree(content).map do |entry|
          { path: "#{name}/#{entry[:path]}", type: entry[:type] }
        end
        [dir_entry] + sub_entries
      end
    end
  end

  # def generate_expected_tree(structure, prefix = "")
  #   tree = structure.flat_map do |name, content|
  #     path = prefix.empty? ? name : File.join(prefix, name)
  #     if content.is_a?(Hash)
  #       ["#{path}/"] + generate_expected_tree(content, path)
  #     else
  #       [path]
  #     end
  #   end
  #   ["./"] + tree.sort
  # end
end
