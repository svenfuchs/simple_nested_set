require 'active_support/core_ext/hash/slice'

module SimpleNestedSet
  module ClassMethods
    def before_move(*args, &block)
      set_callback(:move, :before, *args, &block)
    end

    def after_move(*args, &block)
      set_callback(:move, :after, *args, &block)
    end

    # Returns all roots recursively pre-populated with their children associations
    def trees(scope = nil)
      nodes = nested_set_class.scope(scope)
      nodes.select(&:root?).each do |root|
        root.nested_set.populate_associations(nodes.select { |node| node.descendent_of?(root) })
      end
    end

    # Returns the first root node (with the given scope if any)
    def root(scope = nil)
      roots(scope).first
    end

    # Returns root nodes (with the given scope if any)
    def roots(scope = nil)
      nested_set_class.scope(scope).without_parent
    end

    # Returns roots when multiple roots (or virtual root, which is the same)
    def leaves(scope = nil)
      nested_set_class.scope(scope).with_leaves
    end

    def without_node(id)
      where(arel_table[:id].not_eq(id)).order(:lft)
    end

    def without_parent
      with_parent(nil)
    end

    def with_parent(parent_id)
      where(:parent_id => parent_id).order(:lft)
    end

    def with_ancestors(lft, rgt, opts = {})
      if opts.fetch(:include_self, false)
        where(arel_table[:lft].lteq(lft).and(arel_table[:rgt].gteq(rgt))).order(:lft)
      else
        where(arel_table[:lft].lt(lft).and(arel_table[:rgt].gt(rgt))).order(:lft)
      end
    end

    def with_descendants(lft, rgt, opts = {})
      if opts.fetch(:include_self, false)
        where(arel_table[:lft].gteq(lft).and(arel_table[:rgt].lteq(rgt))).order(:lft)
      else
        where(arel_table[:lft].gt(lft).and(arel_table[:rgt].lt(rgt))).order(:lft)
      end
    end

    def with_left_sibling(lft)
      where(:rgt => lft - 1).order(:lft)
    end

    def with_right_sibling(rgt)
      where(:lft => rgt + 1).order(:lft)
    end

    def with_leaves
      # where("#{arel_table[:lft].to_sql} = #{arel_table[:rgt].to_sql} - 1").order(:lft)
      where("#{arel_table.name}.lft = #{arel_table.name}.rgt - 1").order(:lft)
    end

    def nested_set_transaction(sort_order = :id)
      begin
        nested_set_class.move_after_save = false
        self.transaction do
          yield self
          # nested_set_class.new(self).rebuild_by_parents!(sort_order)
          Rebuild::FromParents.new.run(self, sort_order)
        end
      ensure
        nested_set_class.move_after_save = true
      end
    end
  end
end
