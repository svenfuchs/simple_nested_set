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

  # ASSOCIATIONS

  test "association.create moves the created node" do
    owner = NodeOwner.create!
    owner.nodes << root

    node_1 = owner.nodes.create!(:parent_id => root.id, :scope_id => 1)
    node_2 = owner.nodes.create!(:parent_id => node_1.id, :scope_id => 1)

    assert_equal root, node_1.parent
    assert_equal node_1, node_2.parent
  end

  test "node.children.create moves the created node" do
    node_1 = root.children.create!(:parent_id => root.id, :scope_id => 1)
    node_2 = root.children.create!(:parent_id => node_1.id, :scope_id => 1)

    assert_equal root, node_1.parent
    assert_equal node_1, node_2.parent
  end

  # BULK CREATION

  test "creating a bunch of nodes on an association at once works" do
    owner = NodeOwner.create!(:nodes_attributes => [{ :slug => 'foo', :scope_id => 3 }, { :slug => 'bar', :scope_id => 3 }])
    owner.reload
    owner.nodes.reset

    foo, bar = owner.nodes.first, owner.nodes.last

    assert_equal ['foo', 1, 2, 'foo'], [foo.slug, foo.lft, foo.rgt, foo.path]
    assert_equal ['bar', 3, 4, 'bar'], [bar.slug, bar.lft, bar.rgt, bar.path]
  end
end
