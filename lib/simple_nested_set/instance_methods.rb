require 'active_support/core_ext/hash/keys'

module SimpleNestedSet
  module InstanceMethods
    def nested_set
      @nested_set ||= nested_set_class.new(self)
    end

    def update_attributes(attributes)
      move_by_attributes(attributes)
      super
    end

    def update_attributes!(attributes)
      move_by_attributes(attributes)
      super
    end

    # recursively populates the parent and children associations of self and
    # all descendants using one query
    def load_tree
      nested_set.populate_associations(descendants)
      self
    end

    # Returns true if the node has the same scope as the given node
    def same_scope?(other)
      nested_set.scope_names.all? { |scope| self.send(scope) == other.send(scope) }
    end

    # Returns the level of this object in the tree, root level is 0
    def level
      parent_id.nil? ? 0 : ancestors.count
    end

    # Returns true if this is a root node.
    def root?
      parent_id.blank?
    end

    # Returns true if this is a child node
    def child?
      !root?
    end

    # Returns true if this is a leaf node
    def leaf?
      rgt.to_i - lft.to_i == 1
    end

    # compare by left column
    def <=>(other)
      lft <=> other.lft
    end

    # Returns the root
    def root
      root? ? self : ancestors.first
    end

    # Returns the parent
    def parent
      self.class.find(parent_id) unless root?
    end

    # Returns true if this is an ancestor of the given node
    def ancestor_of?(other)
      lft < other.lft && rgt > other.rgt
    end

    # Returns true if this is equal to or an ancestor of the given node
    def self_or_ancestor_of?(other)
      self == other || ancestor_of?(other)
    end

    # Returns an array of all parents
    def ancestors
      nested_set.with_ancestors(lft, rgt)
    end

    # Returns the array of all parents and self
    def self_and_ancestors
      ancestors + [self]
    end

    # Returns true if this is a descendent of the given node
    def descendent_of?(other)
      lft > other.lft && rgt < other.rgt
    end

    # Returns true if this is equal to or a descendent of the given node
    def self_or_descendent_of?(other)
      self == other || descendent_of?(other)
    end

    # Returns a set of all of its children and nested children.
    def descendants
      rgt - lft == 1 ? []  : nested_set.with_descendants(lft, rgt)
    end

    # Returns a set of itself and all of its nested children.
    def self_and_descendants
      [self] + descendants
    end

    # Returns the number of descendants
    def descendants_count
      rgt > lft ? (rgt - lft - 1) / 2 : 0
    end

    # Returns a set of only this entry's immediate children including self
    def self_and_children
      [self] + children
    end

    # Returns true if the node has any children
    def children?
      descendants_count > 0
    end
    alias has_children? children?

    # Returns the array of all children of the parent, except self
    def siblings
      self_and_siblings.without_node(id)
    end

    # Returns the array of all children of the parent, included self
    def self_and_siblings
      nested_set.with_parent(parent_id)
    end

    # Returns the lefthand sibling
    def previous_sibling
      nested_set.with_left_sibling(lft).first
    end
    alias left_sibling previous_sibling

    # Returns the righthand sibling
    def next_sibling
      nested_set.with_right_sibling(rgt).first
    end
    alias right_sibling next_sibling

    # Returns all descendants that are leaves
    def leaves
      rgt - lft == 1 ? []  : nested_set.with_descendants(lft, rgt).with_leaves
    end

    # Moves the node to the child of another node
    def move_to_child_of(node)
      node ? move_to(node, :child) : move_to_root
    end

    # Makes this node a root node
    def move_to_root
      move_to(nil, :root)
    end

    # Moves the node to the left of its left sibling if any
    def move_left
      move_to_left_of(left_sibling) if left_sibling
    end

    # Moves the node to the right of its right sibling if any
    def move_right
      move_to_right_of(right_sibling) if right_sibling
    end

    # Move the node to the left of another node
    def move_to_left_of(node)
      move_to(node, :left)
    end

    # Move the node to the left of another node
    def move_to_right_of(node)
      move_to(node, :right)
    end

    protected

      def move_by_attributes(attributes)
        return unless attributes.detect { |key, value| [:parent_id, :left_id, :right_id].include?(key.to_sym) }

        attributes.symbolize_keys!
        attributes.each { |key, value| attributes[key] = nil if value == 'null' }

        parent_id = attributes[:parent_id] ? attributes[:parent_id] : self.parent_id
        parent = parent_id.blank? ? nil : self.class.find(parent_id)

        # if left_id is given but blank, set right_id to leftmost sibling
        if attributes.has_key?(:left_id) && attributes[:left_id].blank?
          attributes.delete(:left_id)
          siblings = parent ? parent.children : self.class.roots(self)
          attributes[:right_id] = siblings.first.id if siblings.first
        end

        # if right_id is given but blank, set left_id to rightmost sibling
        if attributes.has_key?(:right_id) && attributes[:right_id].blank?
          attributes.delete(:right_id)
          siblings = parent ? parent.children : self.class.roots(self)
          attributes[:left_id] = siblings.last.id if siblings.last
        end

        parent_id, left_id, right_id = [:parent_id, :left_id, :right_id].map do |key|
          value = attributes.delete(key)
          value.blank? ? nil : value.to_i
        end

        protect_inconsistent_move!(parent_id, left_id, right_id)

        if left_id && left_id != id
          move_to_right_of(left_id)
        elsif right_id && right_id != id
          move_to_left_of(right_id)
        elsif parent_id != self.parent_id
          move_to_child_of(parent_id)
        end
      end

      def move_to(target, position)
        # return if _run_before_move_callbacks == false

        transaction do
          target.nested_set if target.is_a?(self.class)
          nested_set.reload

          target = self.class.find(target) if target && !target.is_a?(ActiveRecord::Base)
          protect_impossible_move!(position, target) if target

          bound = case position
            when :child
              target.rgt
            when :left
              target.lft
            when :right
              target.rgt + 1
            when :root
              roots = self.class.roots
              roots.empty? ? 1 : roots.last.rgt + 1
          end

          if bound > rgt
            bound -= 1
            other_bound = rgt + 1
          else
            other_bound = lft - 1
          end

          # there would be no change
          return if bound == rgt || bound == lft

          # we have defined the boundaries of two non-overlapping intervals,
          # so sorting puts both the intervals and their boundaries in order
          a, b, c, d = [lft, rgt, bound, other_bound].sort

          parent_id = case position
            when :child;  target.id
            when :root;   nil
            else          target.parent_id
          end

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
              ELSE parent_id END,

            level = (
              SELECT count(id)
              FROM #{self.class.quoted_table_name} as t
              WHERE t.lft < #{self.class.quoted_table_name}.lft AND rgt > #{self.class.quoted_table_name}.rgt
            )
          sql
          args  = { :a => a, :b => b, :c => c, :d => d, :id => id, :parent_id => parent_id }
          self.class.update_all [sql, args], nested_set.class.conditions(self)

          target.nested_set.reload if target
          nested_set.reload

          # _run_after_move_callbacks
        end
      end

      def protect_impossible_move!(position, target)
        positions = [:child, :left, :right, :root]
        impossible_move!("Position must be one of #{positions.inspect} but is #{position.inspect}.") unless positions.include?(position)
        impossible_move!("A new node can not be moved") if new_record?
        impossible_move!("A node can't be moved to itself") if self == target
        impossible_move!("A node can't be moved to a descendant of itself.") if (lft..rgt).include?(target.lft) && (lft..rgt).include?(target.rgt)
        impossible_move!("A node can't be moved to a different scope") unless same_scope?(target)
      end

      def protect_inconsistent_move!(parent_id, left_id, right_id)
        left = self.class.find(left_id) if left_id
        right = self.class.find(right_id) if right_id

        if left && right && (!left.right_sibling || left.right_sibling.id != right_id)
          inconsistent_move! <<-msg
            Both :left_id (#{left_id.inspect}) and :right_id (#{right_id.inspect}) were given but
            :right_id (#{right_id}) does not refer to the right_sibling (#{left.right_sibling.inspect})
            of the node referenced by :left_id (#{left.inspect})
          msg
        end

        if left && parent_id && left.parent_id != parent_id
          inconsistent_move! <<-msg
            Both :left_id (#{left_id.inspect}) and :parent_id (#{parent_id.inspect}) were given but
            left.parent_id (#{left.parent_id}) does not equal parent_id
          msg
        end

        if right && parent_id && right.parent_id != parent_id
          inconsistent_move! <<-msg
            Both :right_id (#{right_id.inspect}) and :parent_id (#{parent_id.inspect}) were given but
            right.parent_id (#{right.parent_id}) does not equal parent_id
          msg
        end
      end

      def inconsistent_move!(message)
        raise InconsistentMove, "Impossible move: #{message.split("\n").map! { |line| line.strip }.join}"
      end

      def impossible_move!(message)
        raise ImpossibleMove, "Impossible move: #{message.split("\n").map! { |line| line.strip }.join}"
      end
  end
end