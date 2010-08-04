module SimpleNestedSet
  module ActMacro
    def acts_as_nested_set(options = {})
      return if acts_as_nested_set?

      include SimpleNestedSet::InstanceMethods
      extend SimpleNestedSet::ClassMethods

      # TODO get callbacks working
      # define_callbacks :move, :terminator => "result == false"
      # before_move :init_as_node

      before_validation :init_as_node
      before_destroy :prune_branch
      belongs_to :parent, :class_name => self.name
      has_many :children, :foreign_key => :parent_id, :class_name => self.base_class.name

      default_scope :order => :lft

      klass = options[:class] || self
      scopes = Array(options[:scope]).map { |s| s.to_s !~ /_id$/ ? :"#{s}_id" : s }

      nested_set_proc = lambda do |*args|
        args.empty? ? {} : where(nested_set.conditions(*args))
      end

      scope :nested_set, nested_set_proc do
        define_method(:scope_columns) { scopes }
        define_method(:conditions) { |record| scopes.inject({}) { |c, name| c.merge(name => record[name]) } }
      end
    end

    def acts_as_nested_set?
      included_modules.include?(SimpleNestedSet::InstanceMethods)
    end
  end
end