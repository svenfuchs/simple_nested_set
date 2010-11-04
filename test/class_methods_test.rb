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
    assert_equal [child_1, child_2_1].sort, Node.leaves(:scope_id => 1).sort
    assert_equal [unrelated_root], Node.leaves(:scope_id => 2)
  end
end
