module RuboCop
  module Cop
    module Style
      class EndlessMethodComment < Base
        def on_def(node)
          return unless node.endless?
          return unless processed_source.comment_at_line(node.first_line)

          # This explicitly tells RuboCop to ignore CommentedKeyword for this node
          ignore_node(node)

          other_cops = processed_source.registry.cops.select do |cop|
            cop.is_a?(RuboCop::Cop::Style::CommentedKeyword)
          end

          other_cops.each do |cop|
            cop.instance_variable_get(:@processed_source)
               &.diagnostics
               &.select { |d| d.location.line == node.loc.line }
               &.each { |d| d.instance_variable_set(:@status, :disabled) }
          end
        end

        def support_autocorrect?
          false
        end
      end
    end
  end
end
