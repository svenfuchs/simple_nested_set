module SimpleNestedSet
  module Move
    class ByAttributes
      include Protection

      attr_reader :node, :attributes

      delegate :nested_set, :to => :node

      def initialize(node, attributes)
        @node, @attributes = node, attributes
        normalize_attributes!
        protect_inconsistent_move!
      end

      def perform
        move_by_parent_id if move_by_parent_id?

        if path && node.path_changed?
          node.move_to_path(path)
        elsif move_by_left_id?
          move_by_left_id
        elsif move_by_right_id?
          move_by_right_id
        end
      end

      protected

        def move_by_left_id?
          attributes.key?(:left_id) && left_id != node.id
        end

        def move_by_right_id?
          attributes.key?(:right_id) && right_id != node.id
        end

        def move_by_parent_id?
          attributes.key?(:parent_id) && parent_id != node.parent_id
        end

        def move_by_left_id
          node.move_to_right_of(left_id)
        end

        def move_by_right_id
          node.move_to_left_of(right_id)
        end

        def move_by_parent_id
          node.move_to_child_of(parent_id)
        end

        def parent_id
          attributes[:parent_id].blank? ? nil : attributes[:parent_id].to_i
        end

        def left_id
          attributes[:left_id].blank? ? nil : attributes[:left_id].to_i
        end

        def right_id
          attributes[:right_id].blank? ? nil : attributes[:right_id].to_i
        end

        def path
          attributes[:path].blank? ? nil : attributes[:path]
        end

        def normalize_attributes!
          attributes.symbolize_keys! if attributes.respond_to?(:symbolize_keys!)
          attributes.each { |key, value| attributes[key] = nil if value == 'null' }

          [:parent, :left, :right].each do |key|
            attributes[:"#{key}_id"] = attributes.delete(key).id if attributes.key?(key)
          end

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
