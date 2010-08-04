require 'active_support/core_ext/hash/slice'

module SimpleNestedSet
  module ClassMethods
    NESTED_SET_ATTRIBUTES = [:parent_id, :left_id, :right_id]

    def create(attributes)
      with_move_by_attributes(attributes) { super }
    end

    def create!(attributes)
      with_move_by_attributes(attributes) { super }
    end

    # def tree(scope = nil)
    #   roots.with_descendants
    # end

    # Returns the first root node (with the given scope if any)
    def root(scope = nil)
      roots(scope).first
    end

    # Returns root nodes (with the given scope if any)
    def roots(scope = nil)
      nested_set.scope(scope).without_parent
    end

    # Returns roots when multiple roots (or virtual root, which is the same)
    def leaves(scope = nil)
      nested_set.scope(scope).with_leaves
    end

    def without_node(id)
      where(arel_table[:id].not_eq(id))
    end

    def without_parent
      with_parent(nil)
    end

    def with_parent(parent_id)
      where(:parent_id => parent_id)
    end

    def with_ancestors(lft, rgt)
      where(arel_table[:lft].lt(lft).and(arel_table[:rgt].gt(rgt)))
    end

    def with_descendants(lft, rgt)
      where(arel_table[:lft].gt(lft).and(arel_table[:rgt].lt(rgt)))
    end

    def with_left_sibling(lft)
      where(:rgt => lft - 1)
    end

    def with_right_sibling(rgt)
      where(:lft => rgt + 1)
    end

    def with_leaves
      where("#{arel_table[:lft].to_sql} = #{arel_table[:rgt].to_sql} - 1")
    end

    protected

      def with_move_by_attributes(attributes)
        transaction do
          nested_set_attributes = extract_nested_set_attributes!(attributes)
          yield.tap { |record| record.send(:move_by_attributes, nested_set_attributes) }
        end
      end

      def extract_nested_set_attributes!(attributes)
        result = attributes.slice(*NESTED_SET_ATTRIBUTES)
        attributes.except!(*NESTED_SET_ATTRIBUTES)
        result
      end
  end
end