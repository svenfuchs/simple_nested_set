module SimpleNestedSet
  class NestedSet < ActiveRecord::Relation
    include SqlAbstraction

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

      def extract_attributes!(attributes)
        attributes.slice(*SimpleNestedSet::ATTRIBUTES).tap do
          attributes.except!(*(SimpleNestedSet::ATTRIBUTES - [:path]))
        end if attributes.respond_to?(:slice)
      end
    end

    attr_reader :node

    def initialize(*args)
      super(node_class, node_class.arel_table)
      @node = args.first if args.size == 1
      @where_values = self.class.scope(args.first).instance_variable_get(:@where_values) if args.size == 1
      # TODO how to set order(:lft) here? it's now being added on various scopes (see class methods), would be better to have it here.
    end

    def save!
      attributes = node.instance_variable_get(:@_nested_set_attributes)
      node.instance_variable_set(:@_nested_set_attributes, nil)
      move_by_attributes(attributes) unless attributes.blank?
      denormalize!
    end

    # FIXME we don't always want to call this on after_save, do we? it's only relevant when
    # either the structure or the slug has changed
    def denormalize!
      sql = []
      sql << denormalize_level_query if node.has_attribute?(:level)
      sql << denormalize_path_query  if node.has_attribute?(:path)
      update_all(sql.join(',')) unless sql.blank?
    end

    # Returns true if the node has the same scope as the given node
    def same_scope?(other)
      scope_names.all? { |scope| node.send(scope) == other.send(scope) }
    end

    # reload nested set attributes
    def reload
      columns  = [:parent_id, :lft, :rgt]
      columns << :level if node.has_attribute?(:level)
      columns << :path  if node.has_attribute?(:path)

      reloaded = unscoped { find(node.id, :select => columns) }
      node.instance_eval { @attributes.merge!(reloaded.instance_variable_get(:@attributes)) }
      node.parent = nil if node.parent_id.nil?
      node.children.reset
    end

    def attribute_names
      @attribute_names ||= node.attribute_names.select { |attribute| ATTRIBUTES.include?(attribute.to_sym) }
    end

    def populate_associations(nodes)
      node.children.target = nodes.select do |child|
        next unless child.parent_id == node.id
        nodes.delete(child)
        child.nested_set.populate_associations(nodes)
        child.parent = node
      end
    end

    # before validation set lft and rgt to the end of the tree
    def init_as_node
      max_right = maximum(:rgt) || 0
      node.lft, node.rgt = max_right + 1, max_right + 2
    end

    # Prunes a branch off of the tree, shifting all of the elements on the right
    # back to the left so the counts still work.
    def prune_branch
      if node.rgt && node.lft
        transaction do
          diff = node.rgt - node.lft + 1
          delete_all(['lft > ? AND rgt < ?', node.lft, node.rgt])
          update_all(['lft = (lft - ?)', diff], ['lft >= ?', node.rgt])
          update_all(['rgt = (rgt - ?)', diff], ['rgt >= ?', node.rgt])
        end
      end
    end

    def move_by_attributes(attributes)
      Move::ByAttributes.new(node, attributes).perform
    end

    def move_to_path(path)
      node.path, parent_path = path, path.split('/')[0..-2].join('/')
      parent = parent_path.empty? ? nil : node.nested_set.where(:path => parent_path).first
      node.move_to_child_of(parent)
    end

    def move_to(target, position)
      Move::ToTarget.new(node, target, position).perform
    end

    def rebuild_from_paths!
      Rebuild::FromPaths.new.run(self)
    end

    def denormalize_level_query
      # query = arel_table.as(:l)
      # query = query.project('count(id)').
      #         where(query[:lft].lt(arel_table[:lft])).
      #         where(query[:rgt].gt(arel_table[:rgt])).
      #         where(where_clauses.map { |clause| clause.gsub(table_name, 'l') })
      # "level = (#{query.to_sql})"

      scope = where_clauses.map { |clause| clause.gsub(table_name, 'l') }.join(' AND ')
      scope = "AND #{scope}" unless scope.empty?

      %(
        level = (
          SELECT COUNT("l"."id")
          FROM #{table_name} AS l
          WHERE
            l.lft < #{table_name}.lft AND
            l.rgt > #{table_name}.rgt
            #{scope}
        )
      )
    end

    def denormalize_path_query
      # query = arel_table.as(:l)
      # query = query.project(group_concat(db_adapter, :slug)).
      #         where(query[:lft].lteq(arel_table[:lft])).
      #         where(query[:rgt].gteq(arel_table[:rgt])).
      #         where(where_clauses.map { |clause| clause.gsub(table_name, 'l') })
      # "path = (#{query.to_sql})"

      scope = where_clauses.map { |clause| clause.gsub(table_name, 'l') }.join(' AND ')
      scope = "AND #{scope}" unless scope.empty?

      %(
        path = (
          SELECT #{group_concat(db_adapter, :slug)}
          FROM #{table_name} AS l
          WHERE
            l.lft <= #{table_name}.lft AND
            l.rgt >= #{table_name}.rgt
            #{scope}
        )
      )
    end

    def db_adapter
      node.class.connection.instance_variable_get('@config')[:adapter].to_sym
    end
  end
end
