module SimpleNestedSet
  class NestedSet
    attr_reader :owner, :scopes

    def initialize(owner, scopes)
      @owner, @scopes = owner, Array(scopes).map { |s| s.to_s !~ /_id$/ ? :"#{s}_id" : s }
    end

    def scope(scope)
      scope.blank? ? owner.scoped : owner.where(conditions(scope))
    end

    def conditions(scope)
      scopes.inject({}) { |c, name| c.merge(name => scope[name]) }
    end

    # reload left, right, and parent
    def reload(node)
      node.reload(:select => 'lft, rgt, parent_id')
    end

    def populate_associations(node, nodes)
      node.children.target = nodes.select do |child|
        if child.parent_id == node.id
          nodes.delete(child)
          populate_associations(child, nodes)
          child.parent = node
        end
      end
    end

    # before validation set lft and rgt to the end of the tree
    def init_as_node(node)
      unless node.rgt && node.lft
        max_right = scope(node).maximum(:rgt) || 0
        node.lft = max_right + 1
        node.rgt = max_right + 2
      end
    end

    # Prunes a branch off of the tree, shifting all of the elements on the right
    # back to the left so the counts still work.
    def prune_branch(node)
      if node.rgt && node.lft
        scope = self.scope(node)
        diff  = node.rgt - node.lft + 1
        owner.transaction {
          scope.delete_all(['lft > ? AND rgt < ?', node.lft, node.rgt])
          scope.update_all(['lft = (lft - ?)', diff], ['lft >= ?', node.rgt])
          scope.update_all(['rgt = (rgt - ?)', diff], ['rgt >= ?', node.rgt])
        }
      end
    end

    # def lft
    #   owner.arel_table[:lft].to_sql
    # end
    #
    # def rgt
    #   owner.arel_table[:rgt].to_sql
    # end
  end
end