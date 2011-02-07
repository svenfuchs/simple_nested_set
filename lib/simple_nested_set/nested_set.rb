module SimpleNestedSet
  class NestedSet < ActiveRecord::Relation
    include SqlAbstraction

    class_inheritable_accessor :node_class, :scope_names, :move_after_save

    class << self
      def build_class(model, scopes)
        model.const_get(:NestedSet) rescue model.const_set(:NestedSet, Class.new(NestedSet)).tap do |node_class|
          node_class.node_class = model
          node_class.move_after_save = true
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
          attributes.except!(*(SimpleNestedSet::ATTRIBUTES - [:path, :parent, :parent_id]))
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
      attributes = node.instance_variable_get(:@_nested_set_attributes) || {}
      node.instance_variable_set(:@_nested_set_attributes, nil)
      attributes.merge!(:parent_id => node.parent_id) if node.parent_id_changed?

      if self.class.move_after_save
        move_by_attributes(attributes) unless attributes.blank?
        denormalize!
      elsif attributes
        attributes.except(:parent_id).each do |key, value|
          node.update_attribute(key, value)
        end
      end
    end

    # FIXME This needs to be abstracted away into the SqlAbstraction module
    # FIXME we don't always want to call this on after_save, do we? it's only relevant when
    # either the structure or the slug has changed
    def denormalize!
      sql = []

      case db_adapter
      when :mysql, :mysql2
        sql << denormalize_query_mysql(:level) do |table|
          table[:id].count.to_sql
        end if node.has_attribute?(:level)

        sql << denormalize_query_mysql(:path) do |table|
          group_concat(db_adapter, :slug)
        end if node.has_attribute?(:path)
      else
        sql << denormalize_level_query if node.has_attribute?(:level)
        sql << denormalize_path_query  if node.has_attribute?(:path)
      end

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

    def rebuild_from_parents!(sort_order = :id)
      Rebuild::FromParents.new.run(self, sort_order)
    end

    # sqlite3, postgresql
    def denormalize_level_query
      aliaz = arel_table.as(:l)
      query = aliaz.project(aliaz[:id].count).
                    where(aliaz[:lft].lt(arel_table[:lft])).
                    where(aliaz[:rgt].gt(arel_table[:rgt]))
      query = [query.to_sql] + where_clauses.map { |clause| clause.gsub(arel_table.name, 'l') }
      "level = (#{query.join(' AND ')})"
    end

    # sqlite3, postgresql
    def denormalize_path_query
      aliaz = arel_table.as(:l)
      query = aliaz.project(group_concat(db_adapter, :slug)).
                    where(aliaz[:lft].lteq(arel_table[:lft])).
                    where(aliaz[:rgt].gteq(arel_table[:rgt]))
      query = [query.to_sql] + where_clauses.map { |clause| clause.gsub(arel_table.name, 'l') }
      "path = (#{query.join(' AND ')})"
    end

    def denormalize_query_mysql(field)
      synonym = field.to_s.reverse.to_sym
      aliaz = arel_table.as("table_#{synonym}")

      field_sql = yield aliaz

      query = [
        aliaz.project("#{field_sql} AS field_#{synonym}", aliaz[:lft], aliaz[:rgt]).to_sql,
        ' WHERE ',
        where_clauses.map { |clause| clause.gsub(arel_table.name, aliaz.table_alias.to_s) }.join(' AND ')
      ].join

      <<-sql
        #{field} = (
          SELECT #{aliaz.table_alias.to_s}.field_#{synonym}
          FROM (#{query}) AS #{aliaz.table_alias.to_s}
          WHERE #{aliaz[:lft].lt(arel_table[:lft]).to_sql}
            AND #{aliaz[:rgt].gt(arel_table[:rgt]).to_sql}
        )
      sql
    end

    def db_adapter
      node.class.connection.instance_variable_get('@config')[:adapter].to_sym
    end
  end
end
