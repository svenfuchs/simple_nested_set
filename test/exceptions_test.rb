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

  # EXCEPTIONS

  test "moving a node to itself as a parent raises" do
    assert_raises(SimpleNestedSet::Move::Impossible) do
      child_1.move_to_child_of(child_1)
    end
  end

  test "moving a node to itself as an ancestor raises" do
    assert_raises(SimpleNestedSet::Move::Impossible) do
      root.move_to_child_of(child_2_1)
    end
  end

  test "moving a node to the left of itself raises" do
    assert_raises(SimpleNestedSet::Move::Impossible) do
      child_1.move_to_left_of(child_1)
    end
  end

  test "moving a node to the right of itself raises" do
    assert_raises(SimpleNestedSet::Move::Impossible) do
      child_1.move_to_right_of(child_1)
    end
  end

  test "moving a node to a different scope" do
    assert_raises(SimpleNestedSet::Move::Impossible) do
      child_1.move_to_child_of(unrelated_root)
    end
  end

  test "node.update_attributes(:parent_id => parent.id, :left_id => left.id) raises if left.parent_id != parent_id" do
    assert_raises(SimpleNestedSet::Move::Inconsistent) do
      child_2_1.update_attributes!(:parent_id => root.id, :left_id => root.id)
    end
  end

  test "node.update_attributes(:parent_id => parent.id, :right_id => right.id) raises if right.parent_id != parent_id" do
    assert_raises(SimpleNestedSet::Move::Inconsistent) do
      child_2_1.update_attributes!(:parent_id => root.id, :right_id => root.id)
    end
  end

  test "node.update_attributes(:left_id => left.id, :right_id => right.id) raises unless right_id refers to the right_sibling of left" do
    assert_raises(SimpleNestedSet::Move::Inconsistent) do
      child_2_1.update_attributes!(:left_id => root.id, :right_id => root.id)
    end
  end

  test "Inconsistent Move is raised if the given parent_id does not match left.parent_id" do
    assert_raises(SimpleNestedSet::Move::Inconsistent) do
      child_2_1.update_attributes!(:left_id => root.id, :parent_id => child_2.id)
    end
  end

  test "Inconsistent Move is not raised if there is only a type error" do
    assert_nothing_raised(SimpleNestedSet::Move::Inconsistent) do
      child_2_1.update_attributes!(:left_id => child_2.id, :parent_id => "#{child_2.parent_id}")
      child_2_1.update_attributes!(:left_id => "#{child_2.id}", :parent_id => child_2.parent_id)
    end
  end
end
