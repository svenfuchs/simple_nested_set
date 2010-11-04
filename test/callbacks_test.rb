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

  # CALLBACKS

  test "before_move get's called after a new node was created and before it is now moved to its new parent" do
    parent_id = false
    Node.send(:before_move) { |node| parent_id = node.parent_id }
    Node.create!(:scope_id => 1, :parent_id => child_2.id)
    assert_nil parent_id
  end

  test "before_move get's called before an existing node is moved" do
    parent_id = false
    Node.send(:before_move) { |node| parent_id = node.parent_id }
    child_2_1.move_to_left_of(child_1)
    assert_equal child_2.id, parent_id
  end

  test "after_move get's called after a new node was created and before it is now moved to its new parent" do
    parent_id = false
    Node.send(:after_move) { |node| parent_id = node.parent_id }
    Node.create!(:scope_id => 1, :parent_id => child_2.id)
    assert_equal child_2.id, parent_id
  end

  test "after_move get's called before an existing node is moved" do
    parent_id = false
    Node.send(:after_move) { |node| parent_id = node.parent_id }
    child_2.move_to_left_of(child_1)
    assert_equal child_1.parent_id, parent_id
  end
end
