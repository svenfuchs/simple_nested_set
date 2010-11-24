require 'active_support/core_ext/hash/keys'

module SimpleNestedSet
  module InstanceMethods
    def nested_set
      @_nested_set ||= nested_set_class.new(self)
    end

    def changed?
      super || @_nested_set_attributes
    end

    def attributes=(attributes, *args)
      @_nested_set_attributes = nested_set_class.extract_attributes!(attributes)
      super(attributes, *args)
    end

    # recursively populates the parent and children associations of self and
    # all descendants using one query
    def load_tree
      nested_set.populate_associations(descendants)
      self
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
    def ancestors(opts = {})
      nested_set.with_ancestors(lft, rgt, opts)
    end

    # Returns the array of all parents and self
    def self_and_ancestors
      ancestors(:include_self => true)
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
    def descendants(opts = {})
      nested_set.with_descendants(lft, rgt, opts)
    end

    # Returns a set of itself and all of its nested children.
    def self_and_descendants
      descendants(:include_self => true)
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
      node ? nested_set.move_to(node, :child) : move_to_root
    end

    # Makes this node a root node
    def move_to_root
      nested_set.move_to(nil, :root)
    end

    # Moves the node to the left of its left sibling if any
    def move_left
      move_to_left_of(left_sibling) if left_sibling
    end

    # Moves the node to the right of its right sibling if any
    def move_right
      move_to_right_of(right_sibling) if right_sibling
    end

    # Move the node to the left of another node. If this other node is nil then
    # this means the node is to be made the rightmost sibling.
    def move_to_left_of(node)
      if node
        nested_set.move_to(node, :left)
      elsif right_most = siblings.last
        move_to_right_of(right_most)
      end
    end

    # Move the node to the left of another node. If this other node is nil then
    # this means the node is to be made the leftmost sibling.
    def move_to_right_of(node)
      if node
        nested_set.move_to(node, :right)
      elsif left_most = siblings.first
        move_to_left_of(left_most)
      end
    end

    # Makes this node to the given path
    def move_to_path(path)
      nested_set.move_to_path(path)
    end
  end
end
