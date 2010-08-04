module SimpleNestedSet
  module Move
    class Inconsistent < ActiveRecord::ActiveRecordError ; end
    class Impossible   < ActiveRecord::ActiveRecordError ; end

    module Protection
      def protect_impossible_move!
        positions = [:child, :left, :right, :root]
        impossible_move!("A new node can not be moved") if node.new_record?
        impossible_move!("Position must be one of #{positions.inspect} but is #{position.inspect}.") unless positions.include?(position)
        impossible_move!("A new node can not be moved") if node.new_record?
        impossible_move!("A node can't be moved to itself") if node == target
        impossible_move!("A node can't be moved to a descendant of itself.") if target && (node.lft..node.rgt).include?(target.lft) && (node.lft..node.rgt).include?(target.rgt)
        impossible_move!("A node can't be moved to a different scope") if target && !nested_set.same_scope?(target)
      end

      def protect_inconsistent_move!
        left  = nested_set.find(left_id)  if left_id
        right = nested_set.find(right_id) if right_id

        if left && right && (!left.right_sibling || left.right_sibling.id != right_id)
          inconsistent_move! <<-msg
            Both :left_id (#{left_id.inspect}) and :right_id (#{right_id.inspect}) were given but
            :right_id (#{right_id}) does not refer to the right_sibling (#{left.right_sibling.inspect})
            of the node referenced by :left_id (#{left.inspect})
          msg
        end

        if left && parent_id && left.parent_id != parent_id
          inconsistent_move! <<-msg
            Both :left_id (#{left_id.inspect}) and :parent_id (#{parent_id.inspect}) were given but
            left.parent_id (#{left.parent_id}) does not equal parent_id
          msg
        end

        if right && parent_id && right.parent_id != parent_id
          inconsistent_move! <<-msg
            Both :right_id (#{right_id.inspect}) and :parent_id (#{parent_id.inspect}) were given but
            right.parent_id (#{right.parent_id}) does not equal parent_id
          msg
        end
      end

      def inconsistent_move!(message)
        raise Inconsistent, "Impossible move: #{message.split("\n").map! { |line| line.strip }.join}"
      end

      def impossible_move!(message)
        raise Impossible, "Impossible move: #{message.split("\n").map! { |line| line.strip }.join}"
      end
    end
  end
end