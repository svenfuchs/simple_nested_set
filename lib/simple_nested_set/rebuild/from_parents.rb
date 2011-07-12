module SimpleNestedSet
  module Rebuild
    class FromParents
      include SqlAbstraction

      attr_accessor :num

      def initialize
        @num = 0
      end

      def run(nested_set, sort_order = :id)
        nested_set.where(:parent_id => nil).update_all(:parent_id => 0)

        order_columns = ([:parent_id] + Array[sort_order]).uniq.compact

        db_adapter = nested_set.first.class.connection.instance_variable_get('@config')[:adapter].to_sym

        order_clause = order_columns.map do |col|
          order_by(db_adapter, col)
        end

        nodes = if nested_set.respond_to?(:except)
                  nested_set.except(:order).order(order_clause)
                else
                  nested_set.reorder(order_clause)
                end.to_a

        renumber(nodes.dup)
        result = nodes.each(&:save)

        nested_set.where(:parent_id => 0).update_all(:parent_id => nil)

        result
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
        if child.root? || child.parent_id == 0
          false
        elsif direct_child?(node, child)
          true
        else
          # recurse to find indirect children,
          # i.e. the child is one of the grandchildren of the node
          child?(node, child.parent)
        end
      end

      def direct_child? node, child
        child.parent_id == node.id
      end
    end
  end
end
