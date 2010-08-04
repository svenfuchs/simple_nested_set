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

    # Returns the first root node (with the given scope if any)
    def root(*args)
      nested_set(*args).first(:conditions => { :parent_id => nil })
    end

    # Returns root nodes (with the given scope if any)
    def roots(*args)
      nested_set(*args).scoped(:conditions => { :parent_id => nil } )
    end

    # Returns roots when multiple roots (or virtual root, which is the same)
    def leaves(*args)
      nested_set(*args).scoped(:conditions => 'lft = rgt - 1' )
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