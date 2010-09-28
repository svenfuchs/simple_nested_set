module SimpleNestedSet
  module Inspect
    def inspect_tree(attributes = [:id, :lft, :rgt, :parent_id, :slug, :path, :level])
      if is_a?(Class)
        nodes = all
        ".\n" << with_exclusive_scope { Inspect.tree(nodes) }
      else
        ".\n" << Inspect.tree([self])
      end
    end

    class << self
      def tree(nodes, indent = '')
        nodes.inject('') do |out, node|
          last = node == nodes.last
          out << line(node, indent, last)
          out << tree(node.children, next_indent(indent, last))
        end
      end

      def line(node, indent, last)
        "#{indent}#{last ? '└' : '├'}── #{node.class.name} id: #{node.id}\n"
      end

      def next_indent(indent, last)
        "#{indent}#{last ? '    ' : '|   '}"
      end
    end
  end
end