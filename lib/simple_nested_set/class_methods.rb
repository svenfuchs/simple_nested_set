require 'active_support/core_ext/hash/slice'

module SimpleNestedSet
  module ClassMethods
    def create!(attributes)
      transaction do
        attributes, nested_set_attributes = extract_nested_set_attributes!(attributes)
        record = super
        record.send(:move_by_attributes, nested_set_attributes)
        record
      end
    end
    
    # def create!(attributes)
    #   transaction do
    #     move_by_attributes(attributes)
    #     super
    #   end
    # end
    
    # Returns the single root
    def root(*args)
      nested_set(*args).first(:conditions => { :parent_id => nil })
    end

    # Returns roots when multiple roots (or virtual root, which is the same)
    def roots(*args)
      nested_set(*args).scoped(:conditions => { :parent_id => nil } )
    end
    
    def leaves(*args)
      nested_set(*args).scoped(:conditions => 'lft = rgt - 1' )
    end
    
    protected
      
      def extract_nested_set_attributes!(attributes)
        nested_set_keys = [:parent_id, :left_id, :right_id]
        [attributes.except(*nested_set_keys), attributes.slice(*nested_set_keys)]
      end
  end
end