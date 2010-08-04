module SimpleNestedSet
  class NestedSet
    class_inheritable_accessor :owner_class, :scope_names

    class << self
      def scope(scope)
        scope.blank? ? owner_class.scoped : owner_class.where(conditions(scope))
      end

      def conditions(scope)
        scope_names.inject({}) { |c, name| c.merge(name => scope[name]) }
      end
    end

    attr_reader :node

    def initialize(node = nil)
      @node = node
    end

    def scoped
      @scoped ||= self.class.scope(node)
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
        max_right = scoped.maximum(:rgt) || 0
        node.lft = max_right + 1
        node.rgt = max_right + 2
      end
    end

    # Prunes a branch off of the tree, shifting all of the elements on the right
    # back to the left so the counts still work.
    def prune_branch
      if node.rgt && node.lft
        diff  = node.rgt - node.lft + 1
        owner_class.transaction {
          scoped.delete_all(['lft > ? AND rgt < ?', node.lft, node.rgt])
          scoped.update_all(['lft = (lft - ?)', diff], ['lft >= ?', node.rgt])
          scoped.update_all(['rgt = (rgt - ?)', diff], ['rgt >= ?', node.rgt])
        }
      end
    end

    # def lft
    #   owner_class.arel_table[:lft].to_sql
    # end
    #
    # def rgt
    #   owner_class.arel_table[:rgt].to_sql
    # end

    def method_missing(name, *args, &block)
      scoped.respond_to?(name) ? scoped.send(name, *args, &block) : super
    end
  end
end