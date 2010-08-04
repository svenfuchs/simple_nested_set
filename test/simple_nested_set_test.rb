require File.expand_path('../test_helper', __FILE__)

class SimpleNestedSetTest < Test::Unit::TestCase
  def setup
    super
    @root, @child_1, @child_2, @child_2_1 = Node.all(:conditions => { :scope_id => 1 })
    @unrelated_root = Node.first(:conditions => { :scope_id => 2 })
    @nodes = [root, child_1, child_2, child_2_1]
  end

  attr_reader :nodes, :root, :child_1, :child_2, :child_2_1, :unrelated_root


  # CLASS METHODS

  test "a newly created node's position is positioned as the rightmost root if left_id or right_id were undefined" do
    assert_equal root, Node.create!(:scope_id => 1).left_sibling
    assert_equal unrelated_root, Node.create!(:scope_id => 2).left_sibling
  end

  test "a newly created node's position is positioned as the rightmost child of the node referenced by :parent_id if given" do
    node = Node.create!(:scope_id => 1, :parent_id => child_2.id)
    assert_equal child_2, node.parent
    assert_equal child_2_1, node.left_sibling
  end

  test "a newly created node's position is positioned to the left of the node referenced by :left_id if given" do
    node = Node.create!(:scope_id => 1, :left_id => child_1.id)
    assert_equal root, node.parent
    assert_equal child_1, node.left_sibling
  end

  test "a newly created node's position is positioned to the right of the node referenced by :right_id if given" do
    node = Node.create!(:scope_id => 1, :right_id => child_1.id)
    assert_equal root, node.parent
    assert_equal child_1, node.right_sibling
  end

  test "Node.root returns the first root node" do
    assert_equal root, Node.root
    assert_equal root, Node.root(:scope_id => 1)
    assert_equal unrelated_root, Node.root(:scope_id => 2)
  end

  test "Node.roots returns all root nodes" do
    assert_equal [root, unrelated_root], Node.roots
    assert_equal [root], Node.roots(:scope_id => 1)
    assert_equal [unrelated_root], Node.roots(:scope_id => 2)
  end

  test "Node.leaves returns all leaves" do
    assert_equal [child_1, child_2_1], Node.leaves(:scope_id => 1)
    assert_equal [unrelated_root], Node.leaves(:scope_id => 2)
  end


  # SCOPES

  test "Node.nested_set(:scope_id => 1) scopes to the given scope" do
    assert_equal nodes, Node.nested_set(:scope_id => 1)
  end


  # CALLBACKS

  test "before_move callback gets called" do
    assert_equal 'foo with before_move callback!', CallbackNode.create!(:name => 'foo').name
  end


  # INSTANCE METHODS

  test "load_tree recursively populates the parent and children associations of self and all descendants" do
    root.load_tree

    assert root.children.loaded?
    assert_equal [child_1, child_2], root.children

    assert root.children.first.children.loaded?
    assert_equal [], root.children.first.children
    assert root.children.first.parent.loaded?
    assert_equal root, root.children.first.parent

    assert root.children.last.children.loaded?
    assert_equal [child_2_1], root.children.last.children
    assert root.children.last.parent.loaded?
    assert_equal root, root.children.last.parent

    assert root.children.last.children.first.children.loaded?
    assert_equal [], root.children.last.children.first.children
    assert root.children.last.children.first.parent.loaded?
    assert_equal child_2, root.children.last.children.first.parent
  end

  test "node.root? returns true if the node is a root, false otherwise" do
    assert root.root?
    assert !child_1.root?
    assert !child_2.root?
    assert !child_2_1.root?
  end

  test "node.child? returns true if the node is a child, false otherwise" do
    assert !root.child?
    assert child_1.child?
    assert child_2.child?
    assert child_2_1.child?
  end

  test "node.leaf? returns true if the node is a leaf, false otherwise" do
    assert !root.leaf?
    assert child_1.leaf?
    assert !child_2.leaf?
    assert child_2_1.leaf?
  end

  test "node.<=>(other) compares the node to the given other node based on their lft column" do
    assert_equal [0, -1, -1, -1], nodes.map { |node| root <=> node }
    assert_equal [1, 0, -1, -1],  nodes.map { |node| child_1 <=> node }
    assert_equal [1, 1, 0, -1],   nodes.map { |node| child_2 <=> node }
    assert_equal [1, 1, 1, 0],    nodes.map { |node| child_2_1 <=> node }
  end

  test "node.root returns to node's topmost ancestor" do
    assert_equal root, root.root
    assert_equal root, child_1.root
    assert_equal root, child_2.root
    assert_equal root, child_2_1.root
  end

  test "node.parent returns the parent node for a child, nil otherwise" do
    assert_nil root.parent
    assert_equal root, child_1.parent
    assert_equal root, child_2.parent
    assert_equal child_2, child_2_1.parent
  end

  test "node.ancestors returns the node's ancestors" do
    assert_equal [], root.ancestors
    assert_equal [root], child_1.ancestors
    assert_equal [root], child_2.ancestors
    assert_equal [root, child_2], child_2_1.ancestors
  end

  test "node.self_and_ancestors returns the node and the node's ancestors" do
    assert_equal [root], root.self_and_ancestors
    assert_equal [root, child_1], child_1.self_and_ancestors
    assert_equal [root, child_2], child_2.self_and_ancestors
    assert_equal [root, child_2, child_2_1], child_2_1.self_and_ancestors
  end

  test "node.siblings returns the node's siblings" do
    assert_equal [], root.siblings
    assert_equal [child_2], child_1.siblings
    assert_equal [child_1], child_2.siblings
    assert_equal [], child_2_1.siblings
  end

  test "node.self_and_siblings returns the node and the node's siblings" do
    assert_equal [root], root.self_and_siblings
    assert_equal [child_1, child_2], child_1.self_and_siblings
    assert_equal [child_1, child_2], child_2.self_and_siblings
    assert_equal [child_2_1], child_2_1.self_and_siblings
  end

  test "node.leaves returns all of this node's descendants that are leaves" do
    assert_equal [child_1, child_2_1], root.leaves
    assert_equal [], child_1.leaves
    assert_equal [child_2_1], child_2.leaves
    assert_equal [], child_2_1.leaves
  end

  test "node.descendants returns the node's descendants" do
    assert_equal [child_1, child_2, child_2_1], root.descendants
  end

  test "node.self_and_descendants returns the node and the node's descendants" do
    assert_equal [root, child_1, child_2, child_2_1], root.self_and_descendants
  end

  test "node.descendants_count returns the node's number of children" do
    assert_equal 3, root.descendants_count
    assert_equal 0, child_1.descendants_count
    assert_equal 1, child_2.descendants_count
    assert_equal 0, child_2_1.descendants_count
  end

  test "node.children? returns true if the node has children, false otherwise" do
    assert root.children?
    assert !child_1.children?
    assert child_2.children?
    assert !child_2_1.children?
  end

  test "node.children returns the node's children" do
    assert_equal [child_1, child_2], root.children
    assert_equal [], child_1.children
    assert_equal [child_2_1], child_2.children
    assert_equal [], child_2_1.children
  end

  test "node.ancestor_of?(other) returns true if the node is an ancestor of the given other node, false otherwise" do
    assert_equal [false, true, true, true],    nodes.map { |node| root.ancestor_of?(node) }
    assert_equal [false, false, false, false], nodes.map { |node| child_1.ancestor_of?(node) }
    assert_equal [false, false, false, true],  nodes.map { |node| child_2.ancestor_of?(node) }
    assert_equal [false, false, false, false], nodes.map { |node| child_2_1.ancestor_of?(node) }
  end

  test "node.self_or_ancestor_of? returns true if the node equals the given node or is an ancestor of the given node, false otherwise" do
    assert_equal [true, true, true, true],    nodes.map { |node| root.self_or_ancestor_of?(node) }
    assert_equal [false, true, false, false], nodes.map { |node| child_1.self_or_ancestor_of?(node) }
    assert_equal [false, false, true, true],  nodes.map { |node| child_2.self_or_ancestor_of?(node) }
    assert_equal [false, false, false, true], nodes.map { |node| child_2_1.self_or_ancestor_of?(node) }
  end

  test "node.descendent_of? returns true if the node is a descendent of the given node, false otherwise" do
    assert_equal [false, false, false, false], nodes.map { |node| root.descendent_of?(node) }
    assert_equal [true, false, false, false],  nodes.map { |node| child_1.descendent_of?(node) }
    assert_equal [true, false, false, false],  nodes.map { |node| child_2.descendent_of?(node) }
    assert_equal [true, false, true, false],   nodes.map { |node| child_2_1.descendent_of?(node) }
  end

  test "node.self_or_descendent_of? returns true if the node equals the given node or is a descendent of the given node, false otherwise" do
    assert_equal [true, false, false, false], nodes.map { |node| root.self_or_descendent_of?(node) }
    assert_equal [true, true, false, false],  nodes.map { |node| child_1.self_or_descendent_of?(node) }
    assert_equal [true, false, true, false],  nodes.map { |node| child_2.self_or_descendent_of?(node) }
    assert_equal [true, false, true, true],   nodes.map { |node| child_2_1.self_or_descendent_of?(node) }
  end

  test "node.level returns the node's level" do
    assert_equal [0, 1, 1, 2], nodes.map { |node| node.level }
  end

  test "node.same_scope? returns true if the node has the same scope as the given node, false otherwise" do
    assert root.same_scope?(root)
    assert root.same_scope?(child_1)
    assert !root.same_scope?(unrelated_root)
  end

  test "node.previous_sibling returns the left sibling if any, nil otherwise" do
    assert_nil root.previous_sibling
    assert_nil child_1.previous_sibling
    assert_equal child_1, child_2.previous_sibling
    assert_nil child_2_1.previous_sibling
  end

  test "node.next_sibling returns the right sibling if any, nil otherwise" do
    assert_nil root.next_sibling
    assert_equal child_2, child_1.next_sibling
    assert_nil child_2.next_sibling
    assert_nil child_2_1.next_sibling
  end


  # MOVING

  test "node.move_left moves the node to the left of its left sibling if any" do
    child_2.move_left
    assert_equal child_1, child_2.right_sibling

    child_2.move_left
    assert_equal child_1, child_2.right_sibling

    assert_nothing_raised { root.move_left }
  end

  test "node.move_right moves the node to the left of its right sibling if any" do
    child_1.move_right
    assert_equal child_2, child_1.left_sibling

    child_1.move_right
    assert_equal child_2, child_1.left_sibling

    assert_nothing_raised { root.move_right }
  end

  test "node.move_to_left_of(other) moves the node to the left of the given node" do
    child_2_1.move_to_left_of(child_2)
    assert_equal child_2_1, child_2.left_sibling
    assert_equal root, child_2_1.parent

    child_2_1.move_to_left_of(root)
    assert_equal child_2_1, root.left_sibling
    assert_nil child_2_1.parent
  end

  test "node.move_to_right_of(other) moves the node to the right of the given node" do
    child_2_1.move_to_right_of(child_2)
    assert_equal child_2_1, child_2.right_sibling
    assert_equal root, child_2_1.parent

    child_2_1.move_to_right_of(root)
    assert_equal child_2_1, root.right_sibling
    assert_nil child_2_1.parent
  end

  test "node.update_attributes(:parent_id => parent.id) moves the node to the new parent (as the rightmost node)" do
    child_2_1.update_attributes!(:parent_id => root.id)
    assert_equal root, child_2_1.parent
    assert_equal child_2, child_2_1.left_sibling
  end

  test "node.update_attributes(:parent_id => '') makes node a root (as the rightmost root)" do
    child_2_1.update_attributes!(:parent_id => '')
    assert child_2_1.root?
    assert_equal root, child_2_1.left_sibling
  end

  test "node.update_attributes(:left_id => left.id) moves the node to left of the given left node" do
    child_2_1.update_attributes!(:left_id => child_2.id)
    assert_equal root, child_2_1.parent
    assert_equal child_2, child_2_1.left_sibling
  end

  test "node.update_attributes(:left_id => '') makes the node the leftmost (amongst its siblings)" do
    child_2.update_attributes!(:left_id => '')
    assert_equal root, child_2.parent
    assert_equal child_1, child_2.right_sibling
  end

  test "node.update_attributes(:right_id => right.id) moves the node to right of the given right node" do
    child_2_1.update_attributes!(:right_id => child_2.id)
    assert_equal root, child_2_1.parent
    assert_equal child_2, child_2_1.right_sibling
  end

  test "node.update_attributes(:right_id => '') makes the node the rightmost (amongst its siblings)" do
    child_1.update_attributes!(:right_id => '')
    assert_equal root, child_1.parent
    assert_equal child_2, child_1.left_sibling
  end

  test "node.update_attributes(:parent_id => parent.id, :left_id => left.id) moves the node to left of the given left node" do
    child_2_1.update_attributes!(:parent_id => root.id, :left_id => child_2.id)
    assert_equal root, child_2_1.parent
    assert_equal child_2, child_2_1.left_sibling
  end

  test "node.update_attributes(:parent_id => parent.id, :right_id => right.id) moves the node to right of the given right node" do
    child_2_1.update_attributes!(:parent_id => root.id, :right_id => child_2.id)
    assert_equal root, child_2_1.parent
    assert_equal child_2, child_2_1.right_sibling
  end


  # DESTROYING

  test "node.destroy destroys all children, too" do
    child_2.destroy
    assert_raises(ActiveRecord::RecordNotFound) { child_2_1.reload }
  end

  test "node.destroy closes resulting gaps in the lft/rgt numbering (1)" do
    child_1.destroy
    assert_equal [[1, 6], [2, 5], [3, 4]], [root, child_2, child_2_1].map { |node| node.reload; [node.lft, node.rgt] }
  end

  test "node.destroy closes resulting gaps in the lft/rgt numbering (3)" do
    child_2_1.destroy
    assert_equal [[1, 6], [2, 3], [4, 5]], [root, child_1, child_2].map { |node| node.reload; [node.lft, node.rgt] }
  end

  test "node.destroy closes resulting gaps in the lft/rgt numbering (2)" do
    child_2.destroy
    assert_equal [[1, 4], [2, 3]], [root, child_1].map { |node| node.reload; [node.lft, node.rgt] }
  end


  # EXCEPTIONS

  test "moving a node to itself as a parent raises" do
    assert_raises(SimpleNestedSet::ImpossibleMove) do
      child_1.move_to_child_of(child_1)
    end
  end

  test "moving a node to itself as an ancestor raises" do
    assert_raises(SimpleNestedSet::ImpossibleMove) do
      root.move_to_child_of(child_2_1)
    end
  end

  test "moving a node to the left of itself raises" do
    assert_raises(SimpleNestedSet::ImpossibleMove) do
      child_1.move_to_left_of(child_1)
    end
  end

  test "moving a node to the right of itself raises" do
    assert_raises(SimpleNestedSet::ImpossibleMove) do
      child_1.move_to_right_of(child_1)
    end
  end

  test "moving a node to a different scope" do
    assert_raises(SimpleNestedSet::ImpossibleMove) do
      child_1.move_to_child_of(unrelated_root)
    end
  end

  test "node.update_attributes(:parent_id => parent.id, :left_id => left.id) raises if left.parent_id != parent_id" do
    assert_raises(SimpleNestedSet::InconsistentMove) do
      child_2_1.update_attributes!(:parent_id => root.id, :left_id => root.id)
    end
  end

  test "node.update_attributes(:parent_id => parent.id, :right_id => right.id) raises if right.parent_id != parent_id" do
    assert_raises(SimpleNestedSet::InconsistentMove) do
      child_2_1.update_attributes!(:parent_id => root.id, :right_id => root.id)
    end
  end

  test "node.update_attributes(:left_id => left.id, :right_id => right.id) raises unless right_id refers to the right_sibling of left" do
    assert_raises(SimpleNestedSet::InconsistentMove) do
      child_2_1.update_attributes!(:left_id => root.id, :right_id => root.id)
    end
  end
end