module SimpleNestedSet
  class NestedSet < ActiveRecord::Relation
    include Protection

    NESTED_SET_ATTRIBUTES = [:parent_id, :left_id, :right_id]

    class_inheritable_accessor :node_class, :scope_names

    class << self
      def build_class(model, scopes)
        model.const_get(:NestedSet) rescue model.const_set(:NestedSet, Class.new(NestedSet)).tap do |node_class|
          node_class.node_class = model
          node_class.scope_names = Array(scopes).map { |s| s.to_s =~ /_id$/ ? s.to_sym : :"#{s}_id" }
        end
      end

      def scope(scope)
        scope.blank? ? node_class.scoped : node_class.where(scope_condition(scope))
      end

      def scope_condition(scope)
        scope_names.inject({}) do |c, name|
          c.merge(name => scope.respond_to?(name) ? scope.send(name) : scope[name])
        end
      end

      def with_move_by_attributes(attributes)
        node_class.transaction do
          nested_set_attributes = extract_nested_set_attributes!(attributes)
          yield.tap { |node| node.nested_set.move_by_attributes(nested_set_attributes) }
        end
      end

      def extract_nested_set_attributes!(attributes)
        result = attributes.slice(*NESTED_SET_ATTRIBUTES)
        attributes.except!(*NESTED_SET_ATTRIBUTES)
        result
      end
    end

    attr_reader :node

    def initialize(*args)
      super(node_class, node_class.arel_table)
      @node = args.first if args.size == 1
      @where_values = self.class.scope(node).instance_variable_get(:@where_values) if node
    end

    # Returns true if the node has the same scope as the given node
    def same_scope?(other)
      scope_names.all? { |scope| node.send(scope) == other.send(scope) }
    end

    # reload left, right, and parent
    def reload
      node.reload(:select => 'lft, rgt, parent_id')
    end

    def populate_associations(nodes)
      node.children.target = nodes.select do |child|
        if child.parent_id == node.id
          nodes.delete(child)
          child.nested_set.populate_associations(nodes)
          child.parent = node
        end
      end
    end

    # before validation set lft and rgt to the end of the tree
    def init_as_node
      unless node.rgt && node.lft
        max_right = maximum(:rgt) || 0
        node.lft = max_right + 1
        node.rgt = max_right + 2
      end
    end

    # Prunes a branch off of the tree, shifting all of the elements on the right
    # back to the left so the counts still work.
    def prune_branch
      if node.rgt && node.lft
        diff  = node.rgt - node.lft + 1
        transaction do
          delete_all(['lft > ? AND rgt < ?', node.lft, node.rgt])
          update_all(['lft = (lft - ?)', diff], ['lft >= ?', node.rgt])
          update_all(['rgt = (rgt - ?)', diff], ['rgt >= ?', node.rgt])
        end
      end
    end

    def move_by_attributes(attributes)
      return unless attributes.detect { |key, value| [:parent_id, :left_id, :right_id].include?(key.to_sym) }

      attributes.symbolize_keys!
      attributes.each { |key, value| attributes[key] = nil if value == 'null' }

      parent_id = attributes[:parent_id] ? attributes[:parent_id] : node.parent_id
      parent = parent_id.blank? ? nil : find(parent_id)

      # if left_id is given but blank, set right_id to leftmost sibling
      if attributes.has_key?(:left_id) && attributes[:left_id].blank?
        attributes.delete(:left_id)
        siblings = parent ? parent.children : node.class.roots(node)
        attributes[:right_id] = siblings.first.id if siblings.first
      end

      # if right_id is given but blank, set left_id to rightmost sibling
      if attributes.has_key?(:right_id) && attributes[:right_id].blank?
        attributes.delete(:right_id)
        siblings = parent ? parent.children : node.class.roots(node)
        attributes[:left_id] = siblings.last.id if siblings.last
      end

      parent_id, left_id, right_id = [:parent_id, :left_id, :right_id].map do |key|
        value = attributes.delete(key)
        value.blank? ? nil : value.to_i
      end

      protect_inconsistent_move!(parent_id, left_id, right_id)

      if left_id && left_id != node.id
        node.move_to_right_of(left_id)
      elsif right_id && right_id != node.id
        node.move_to_left_of(right_id)
      elsif parent_id != node.parent_id
        node.move_to_child_of(parent_id)
      end
    end

    def move_to(target, position)
      Move.new(node, target, position).perform
    end
  end
end