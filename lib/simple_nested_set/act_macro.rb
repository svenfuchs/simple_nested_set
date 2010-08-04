module SimpleNestedSet
  module ActMacro
    def acts_as_nested_set(options = {})
      return if acts_as_nested_set?

      include SimpleNestedSet::InstanceMethods
      extend SimpleNestedSet::ClassMethods

      # TODO get callbacks working
      # define_callbacks :move, :terminator => "result == false"
      # before_move :init_as_node

      before_validation lambda { |r| r.nested_set.init_as_node(r) }
      before_destroy    lambda { |r| r.nested_set.prune_branch(r) }

      belongs_to :parent, :class_name => self.name
      has_many :children, :foreign_key => :parent_id, :class_name => self.base_class.name

      default_scope :order => :lft

      class_inheritable_accessor :nested_set
      self.nested_set = NestedSet.new(self, options[:scope])
    end

    def acts_as_nested_set?
      included_modules.include?(SimpleNestedSet::InstanceMethods)
    end
  end
end