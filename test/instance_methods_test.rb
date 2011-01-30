require File.expand_path('../test_helper', __FILE__)

class NestedSetTest < Test::Unit::TestCase
  include SimpleNestedSet
  include SqlAbstraction

  def setup
    super
    @root      = Node.create!(:slug => 'root',      :scope_id => 1)
    @child_1   = Node.create!(:slug => 'child_1',   :scope_id => 1, :parent_id => root.id)
    @child_2   = Node.create!(:slug => 'child_2',   :scope_id => 1, :parent_id => root.id)
    @child_2_1 = Node.create!(:slug => 'child_2_1', :scope_id => 1, :parent_id => child_2.id)

    @unrelated_root = Node.create!(:slug => 'unrelated_root', :scope_id => 2)

    @nodes = [root, child_1, child_2, child_2_1].map(&:reload)
  end

  def teardown
    super
    Node.reset_callbacks(:move)
  end

  attr_reader :nodes, :root, :child_1, :child_2, :child_2_1, :unrelated_root

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

  test "node.self_and_ancestors should return a relation" do
    assert child_2_1.self_and_ancestors.is_a?(ActiveRecord::Relation)
    assert root.self_and_ancestors.is_a?(ActiveRecord::Relation)
  end

  test "node.siblings returns the node's siblings" do
    assert_equal [], root.siblings
    assert_equal [child_2], child_1.siblings
    assert_equal [child_1], child_2.siblings
    assert_equal [], child_2_1.siblings
  end

  test "node.self_and_siblings returns the node and the node's siblings" do
    child_1.move_right # so we test the sort order, too
    assert_equal [root], root.self_and_siblings
    assert_equal [child_2, child_1], child_1.self_and_siblings
    assert_equal [child_2, child_1], child_2.self_and_siblings
    assert_equal [child_2_1], child_2_1.self_and_siblings
  end

  test "node.self_and_children returns node and the node's children" do
    assert_equal [root, child_1, child_2], root.self_and_children
    assert_equal [child_1], child_1.self_and_children
    assert_equal [child_2, child_2_1], child_2.self_and_children
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

  test "node.descendants returns empty list for a leaf node" do
    assert_equal [], child_2_1.descendants
  end

  test "node.self_and_descendants returns the node and the node's descendants" do
    assert_equal [root, child_1, child_2, child_2_1], root.self_and_descendants
  end

  test "node.self_and_descendants returns only self for leaf nodes" do
    assert_equal [child_1], child_1.self_and_descendants
  end

  test "node.self_and_descendants should return a relation" do
    assert root.self_and_descendants.is_a?(ActiveRecord::Relation)
    assert child_1.self_and_descendants.is_a?(ActiveRecord::Relation)
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
    child_1.move_right # so we test the sort order, too
    assert_equal [child_2, child_1], root.children
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

  test "node.path returns the node's path" do
    assert_equal ['root', 'root/child_1', 'root/child_2', 'root/child_2/child_2_1'], nodes.map { |node| node.path }
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

  test "node.nested_set.same_scope? returns true if the node has the same scope as the given node, false otherwise" do
    assert root.nested_set.same_scope?(root)
    assert root.nested_set.same_scope?(child_1)
    assert !root.nested_set.same_scope?(unrelated_root)
  end
end

