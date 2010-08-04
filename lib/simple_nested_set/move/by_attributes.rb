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
        protect_inconsistent_move!(parent_id, left_id, right_id)
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

          # if left_id is given but blank, set right_id to leftmost sibling
          if attributes.has_key?(:left_id) && attributes[:left_id].blank? && siblings.any?
            attributes[:right_id] = siblings.first.id
          end

          # if right_id is given but blank, set left_id to rightmost sibling
          if attributes.has_key?(:right_id) && attributes[:right_id].blank? && siblings.any?
            attributes[:left_id] = siblings.last.id
          end
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