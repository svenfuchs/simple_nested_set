module SimpleNestedSet
  module Move
    class ToTarget
      include Protection

      attr_reader :node, :target, :position

      delegate :id, :nested_set, :to => :node

      def initialize(node, target, position)
        @node, @target, @position = node, target, position
        @target = nested_set.find(target) if target && !target.is_a?(ActiveRecord::Base)
        protect_impossible_move!
      end

      def perform
        node.run_callbacks(:move) do
          unless bound == node.rgt || bound == node.lft # there would be no change
            nested_set.transaction { update_structure! }
          end
          reload
        end
      end

      def update_structure!
        sql = <<-sql
          lft = CASE
            WHEN lft BETWEEN :a AND :b THEN lft + :d - :b
            WHEN lft BETWEEN :c AND :d THEN lft + :a - :c
            ELSE lft END,

          rgt = CASE
            WHEN rgt BETWEEN :a AND :b THEN rgt + :d - :b
            WHEN rgt BETWEEN :c AND :d THEN rgt + :a - :c
            ELSE rgt END,

          parent_id = CASE
            WHEN id = :id THEN :parent_id
            ELSE parent_id END
        sql

        a, b, c, d = boundaries
        sql = [sql, { :a => a, :b => b, :c => c, :d => d, :id => id, :parent_id => parent_id }]

        # puts ActiveRecord::Base.send(:sanitize_sql_array, sql)
        nested_set.update_all(sql)
      end

      def reload
        target.nested_set.reload if target
        node.nested_set.reload
      end

      def parent_id
        @parent_id ||= case position
          when :child;  target.id
          when :root;   nil
          else          target.parent_id
        end
      end

      def boundaries
        # we have defined the boundaries of two non-overlapping intervals,
        # so sorting puts both the intervals and their boundaries in order
        @boundaries ||= [node.lft, node.rgt, bound, other_bound].sort
      end

      def bound
        @bound ||= begin
          bound = case position
            when :child ; target.rgt
            when :left  ; target.lft
            when :right ; target.rgt + 1
            when :root  ; roots.empty? ? 1 : roots.last.rgt + 1
          end
          bound > node.rgt ? bound - 1 : bound
        end
      end

      # TODO name other_bound in a more reasonable way
      def other_bound
        @other_bound ||= bound > node.rgt ? node.rgt + 1 : node.lft - 1
      end

      def roots
        @roots ||= node.nested_set.roots
      end

      def table_name
        node.class.quoted_table_name
      end
    end
  end
end