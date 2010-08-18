module SimpleNestedSet
  module Move
    class ByAttributes
      class << self
        def attribute_reader(*names)
          names.each do |name|
            define_method(name) { attributes[name].blank? ? nil : attributes[name].to_i }
          end
        end
      end

      include Protection

      attr_reader :node, :attributes
      attribute_reader :parent_id, :left_id, :right_id

      delegate :nested_set, :to => :node

      def initialize(node, attributes)
        @node, @attributes = node, attributes
        normalize_attributes!
        protect_inconsistent_move!
      end

      def perform
        if left_id && left_id != node.id
          node.move_to_right_of(left_id)
        elsif right_id && right_id != node.id
          node.move_to_left_of(right_id)
        elsif parent_id != node.parent_id
          node.move_to_child_of(parent_id)
        end
      end

      protected

        def normalize_attributes!
          attributes.symbolize_keys!
          attributes.each { |key, value| attributes[key] = nil if value == 'null' }

          [:parent, :left, :right].each do |key|
            attributes[:"#{key}_id"] = attributes.delete(key).id if attributes.key?(key)
          end

          # if left_id is given but blank, set right_id to leftmost sibling
          attributes[:right_id] = siblings.first.id if blank_given?(:left_id) && siblings.any?

          # if right_id is given but blank, set left_id to rightmost sibling
          attributes[:left_id]  = siblings.last.id if blank_given?(:right_id) && siblings.any?
        end

        def blank_given?(key)
          attributes.has_key?(key) && attributes[key].blank? && siblings.any?
        end

        def siblings
          @siblings ||= parent ? parent.children : node.nested_set.roots(node)
        end

        def parent
          @parent ||= begin
            parent_id = self.parent_id || node.parent_id
            parent_id.blank? ? nil : nested_set.find(parent_id)
          end
        end
    end
  end
end