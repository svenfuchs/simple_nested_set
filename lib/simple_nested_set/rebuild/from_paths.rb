module SimpleNestedSet
  module Rebuild
    class FromPaths
      attr_writer :num

      def num
        @num ||= 0
      end

      def run(nested_set)
        nodes = nested_set.order(:path).to_a
        renumber(nodes.dup)
        nodes.each(&:save)
      end

      def renumber(nodes)
        until nodes.empty?
          node = nodes.shift
          node.lft = self.num += 1
          num = renumber(extract_children(node, nodes))
          node.rgt = self.num += 1
        end
        num
      end

      def extract_children(node, nodes)
        children = nodes.select { |child| child?(node, child) }
        nodes.replace(nodes - children)
        children
      end

      def child?(node, child)
        child && child.path =~ %r(^#{node.path}/)
      end
    end
  end
end