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

  # MOVING

  test "node.move_path moves the node to the given path (w/ a root path)" do
    child_1.move_to_path(root.path)
    assert child_1.root?
  end

  test "node.move_path moves root node to root position" do
    root.move_to_path(root.path)
    assert root.root?
  end

  test "node.move_path moves the node to the given path (w/ a non-root path)" do
    child_1.move_to_path("#{child_2_1.path}/#{child_1.slug}")
    assert_equal child_2_1, child_1.parent
  end

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
    assert_equal root, child_2.parent

    child_2_1.move_to_left_of(root)
    assert_equal child_2_1, root.left_sibling
    assert_nil child_2_1.parent
  end

  test "node.move_to_left_of(nil) moves the node to the right of the rightmost sibling" do
    child_1.move_to_left_of(nil)
    assert_equal child_2, child_1.left_sibling
    assert_nil child_1.right_sibling
    assert_equal root, child_1.parent
  end

  test "node.move_to_right_of(other) moves the node to the right of the given node" do
    child_2_1.move_to_right_of(child_2)
    assert_equal child_2_1, child_2.right_sibling
    assert_equal root, child_2_1.parent

    child_2_1.move_to_right_of(root)
    assert_equal child_2_1, root.right_sibling
    assert_nil child_2_1.parent
  end

  test "node.move_to_right_of(nil) moves the node to the left of the leftmost sibling" do
    child_2.move_to_right_of(nil)
    assert_nil child_2.left_sibling
    assert_equal child_1, child_2.right_sibling
    assert_equal root, child_2.parent
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

    child_1.reload.update_attributes!(:left_id => '')
    assert_equal root, child_1.parent
    assert_equal child_2, child_1.right_sibling
  end

  test "node.update_attributes(:left_id => '') does nothing to a node w/o siblings" do
    child_2_1.update_attributes!(:left_id => '')
    assert_equal child_2, child_2_1.parent
    assert_nil child_2_1.left_sibling
    assert_nil child_2_1.right_sibling
  end

  test "node.update_attributes(:right_id => right.id) moves the node to right of the given right node" do
    child_2_1.update_attributes!(:right_id => child_2.id)
    assert_equal root, child_2_1.parent
    assert_equal child_2, child_2_1.right_sibling
  end

  test "node.update_attributes(:right_id => '') makes the node the rightmost amongst its siblings" do
    child_1.update_attributes!(:right_id => '')
    assert_equal root, child_1.parent
    assert_equal child_2, child_1.left_sibling

    child_2.reload.update_attributes!(:right_id => '')
    assert_equal root, child_2.parent
    assert_equal child_1, child_2.left_sibling
  end

  test "node.update_attributes(:right_id => '') does nothing to a node w/o siblings" do
    child_2_1.update_attributes!(:right_id => '')
    assert_equal child_2, child_2_1.parent
    assert_nil child_2_1.left_sibling
    assert_nil child_2_1.right_sibling
  end

  test "node.update_attributes(:parent_id => parent.id, :left_id => left.id) moves the node to left of the given left node" do
    child_2_1.update_attributes!(:parent_id => root.id, :left_id => child_2.id)
    assert_equal root, child_2_1.parent
    assert_equal child_2, child_2_1.left_sibling
  end

  test "node.update_attributes(:parent_id => parent.id, :left_id => 'null') moves the node to child of the given parent node" do
    child_1.update_attributes!(:parent_id => child_2.id, :left_id => 'null')
    assert_equal child_2, child_1.parent
    assert_nil child_1.left_sibling
  end

  test "node.update_attributes(:parent_id => 'null', :left_id => 'null') moves the node to the leftmost root node" do
    child_1.update_attributes!(:parent_id => 'null', :left_id => 'null')
    assert_nil child_1.parent
    assert_equal root, child_1.right_sibling
  end

  test "node.update_attributes(:parent_id => parent.id, :right_id => right.id) moves the node to right of the given right node" do
    child_2_1.update_attributes!(:parent_id => root.id, :right_id => child_2.id)
    assert_equal root, child_2_1.parent
    assert_equal child_2, child_2_1.right_sibling
  end

  test "node.update_attributes(:parent_id => parent.id, :right_id => 'null') moves the node to child of the given parent node" do
    child_1.update_attributes!(:parent_id => child_2.id, :right_id => 'null')
    assert_equal child_2, child_1.parent
    assert_nil child_1.right_sibling
  end

  test "node.update_attributes(:parent_id => 'null', :right_id => 'null') moves the node to the rightmost root node" do
    child_1.update_attributes!(:parent_id => 'null', :right_id => 'null')
    assert_nil child_1.parent
    assert_equal root, child_1.left_sibling
  end

  # REGRESSION TEST CASES

  test "nil values for parent are handled properly" do
    assert_nothing_raised do
      Node.create!(:slug => 'nil_value', :parent => nil)
    end
  end

  test "node.parent = parent is equal to node.update_attributes(:parent_id => parent)" do
    child_1_1 = Node.new(:slug => 'child_1_1', :scope_id => 1, :parent => child_1)
    child_1_2 = Node.new(:slug => 'child_1_2', :scope_id => 1) { |node| node.parent = child_1 }

    [child_1_1, child_1_2].each { |node| node.save; node.reload }
    child_1.reload
    assert_equal [child_1_1, child_1_2], child_1.descendants
  end
end
