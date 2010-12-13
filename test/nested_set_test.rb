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

  test "setup builds up a valid nested set" do
    assert_equal [nil,        1, 8, 0], [root.parent_id, root.lft, root.rgt, root.level]
    assert_equal [root.id,    2, 3, 1], [child_1.parent_id, child_1.lft, child_1.rgt, child_1.level]
    assert_equal [root.id,    4, 7, 1], [child_2.parent_id, child_2.lft, child_2.rgt, child_2.level]
    assert_equal [child_2.id, 5, 6, 2], [child_2_1.parent_id, child_2_1.lft, child_2_1.rgt, child_2_1.level]
  end

  # SCOPES

  test "Node::NestedSet.scope(:scope_id => 1) scopes to the given scope" do
    assert_equal nodes, Node::NestedSet.scope(:scope_id => 1)
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

  # REBUILD NESTED SET

  test "rebuild_from_path" do
    child_2_2 = Node.create!(:slug => 'child_2_2', :scope_id => 1, :parent_id => child_2.id)
    child_3   = Node.create!(:slug => 'child_3',   :scope_id => 1, :parent_id => root.id)
    root_2    = Node.create!(:slug => 'root_2',    :scope_id => 1)

    Node.update_all(:lft => 0, :rgt => 0)
    root.nested_set.rebuild_from_paths!
    [root, child_1, child_2, child_2_1, child_2_2, child_3, root_2].map(&:reload)

    assert_equal [1,  12], [root.lft, root.rgt]
    assert_equal [2,  3 ], [child_1.lft, child_1.rgt]
    assert_equal [4,  9 ], [child_2.lft, child_2.rgt]
    assert_equal [5,  6 ], [child_2_1.lft, child_2_1.rgt]
    assert_equal [7,  8 ], [child_2_2.lft, child_2_2.rgt]
    assert_equal [10, 11], [child_3.lft, child_3.rgt]
    assert_equal [13, 14], [root_2.lft, root_2.rgt]
  end

  test "rebuild_from_parents" do
    child_2_2 = Node.create!(:slug => 'child_2_2', :scope_id => 1, :parent_id => child_2.id)
    child_3   = Node.create!(:slug => 'child_3',   :scope_id => 1, :parent_id => root.id)
    root_2    = Node.create!(:slug => 'root_2',    :scope_id => 1)

    Node.update_all(:lft => 0, :rgt => 0)
    root.nested_set.rebuild_from_parents!
    [root, child_1, child_2, child_2_1, child_2_2, child_3, root_2].map(&:reload)

    assert_equal [1,  12], [root.lft, root.rgt]
    assert_equal [2,  3 ], [child_1.lft, child_1.rgt]
    assert_equal [4,  9 ], [child_2.lft, child_2.rgt]
    assert_equal [5,  6 ], [child_2_1.lft, child_2_1.rgt]
    assert_equal [7,  8 ], [child_2_2.lft, child_2_2.rgt]
    assert_equal [10, 11], [child_3.lft, child_3.rgt]
    assert_equal [13, 14], [root_2.lft, root_2.rgt]
  end

  test "rebuild_from_parents denormalizes level" do
    child_2_2 = Node.create!(:slug => 'child_2_2', :scope_id => 1, :parent_id => child_2.id)
    child_3   = Node.create!(:slug => 'child_3',   :scope_id => 1, :parent_id => root.id)
    root_2    = Node.create!(:slug => 'root_2',    :scope_id => 1)

    Node.update_all(:lft => 0, :rgt => 0, :level => 0)
    [root, child_1, child_2, child_2_1, child_2_2, child_3, root_2].each do |node|
      node.reload
      assert_equal 0, node.level
    end

    root.nested_set.rebuild_from_parents!
    [root, child_1, child_2, child_2_1, child_2_2, child_3, root_2].map(&:reload)

    [root, root_2].each do |node|
      assert_equal 0, node.level
    end

    [child_1, child_2, child_3].each do |node|
      assert_equal 1, node.level
    end
    [child_2_1, child_2_2].each do |node|
      assert_equal 2, node.level
    end
  end

  test "rebuild_from_parents with sort_order" do
    child_2_0 = Node.create!(:slug => 'child_2_0', :scope_id => 1, :parent_id => child_2.id)
    child_3   = Node.create!(:slug => 'child_3',   :scope_id => 1, :parent_id => root.id)
    root_2    = Node.create!(:slug => 'root_2',    :scope_id => 1)

    Node.update_all(:lft => 0, :rgt => 0)
    root.nested_set.rebuild_from_parents!(:slug)
    [root, child_1, child_2, child_2_0, child_2_1, child_3, root_2].map(&:reload)

    assert_equal [1,  12], [root.lft, root.rgt]
    assert_equal [2,  3 ], [child_1.lft, child_1.rgt]
    assert_equal [4,  9 ], [child_2.lft, child_2.rgt]
    assert_equal [5,  6 ], [child_2_0.lft, child_2_0.rgt]
    assert_equal [7,  8 ], [child_2_1.lft, child_2_1.rgt]
    assert_equal [10, 11], [child_3.lft, child_3.rgt]
    assert_equal [13, 14], [root_2.lft, root_2.rgt]
  end

  test "save several nodes in a transaction and rebuild_from_parents at the end" do
    # TODO for now, only one scope is supported
    Node.destroy(unrelated_root.id)
    unrelated_root = nil

    # hack to have the node-variables visible both inside and outside the block
    child_2_2 = child_3 = root_2 = second_root_child = 'node_placeholder'

    Node.nested_set_transaction do |klass|
      child_2_2 = klass.create!(:slug => 'child_2_2', :scope_id => 1, :parent_id => child_2.id)
      child_3   = klass.create!(:slug => 'child_3',   :scope_id => 1, :parent_id => root.id)
      root_2    = klass.create!(:slug => 'root_2',    :scope_id => 1)
      second_root_child = klass.create!(:slug => 'child_1_of_2', :scope_id => 1, :parent_id => root_2.id)

      # there should only be an insertion, no movement
      assert_not_equal 7,      child_2_2.lft, '7 would be the left value of a moved node'
      assert_equal child_2.id, child_2_2.parent_id, "PARENT: #{child_2.inspect}, CHILD: #{child_2_2.inspect}"
    end

    [root, child_1, child_2, child_2_1, child_2_2, child_3, root_2, second_root_child].map(&:reload)

    assert_equal [1,  12], [root.lft, root.rgt]
    assert_equal [2,  3 ], [child_1.lft, child_1.rgt]
    assert_equal [4,  9 ], [child_2.lft, child_2.rgt]
    assert_equal [5,  6 ], [child_2_1.lft, child_2_1.rgt]
    assert_equal [7,  8 ], [child_2_2.lft, child_2_2.rgt]
    assert_equal [10, 11], [child_3.lft, child_3.rgt]
    assert_equal [13, 16], [root_2.lft, root_2.rgt]
    assert_equal [14, 15], [second_root_child.lft, second_root_child.rgt]
  end

  test "save several nodes in a transaction and rebuild_from_parents with sort_order at the end" do
    # TODO for now, only one scope is supported
    Node.destroy(unrelated_root.id)
    unrelated_root = nil

    # hack to have the node-variables visible both inside and outside the block
    child_2_0 = child_3 = root_2 = 'node_placeholder'

    Node.nested_set_transaction(:slug) do |klass|
      child_2_0 = klass.create!(:slug => 'a slug', :scope_id => 1, :parent_id => child_2.id)
      child_3   = klass.create!(:slug => 'child_3',   :scope_id => 1, :parent_id => root.id)
      root_2    = klass.create!(:slug => 'root_2',    :scope_id => 1)

      # there should only be an insertion, no movement
      assert_not_equal 7,      child_2_0.lft, '7 would be the left value of a moved node'
      assert_equal child_2.id, child_2_0.parent_id, "PARENT: #{child_2.inspect}, CHILD: #{child_2_0.inspect}"
    end

    [root, child_1, child_2, child_2_1, child_2_0, child_3, root_2].map(&:reload)

    assert_equal [1,  12], [root.lft, root.rgt]
    assert_equal [2,  3 ], [child_1.lft, child_1.rgt]
    assert_equal [4,  9 ], [child_2.lft, child_2.rgt]
    assert_equal [5,  6 ], [child_2_0.lft, child_2_0.rgt], child_2_0.slug
    assert_equal [7,  8 ], [child_2_1.lft, child_2_1.rgt], child_2_1.slug
    assert_equal [10, 11], [child_3.lft, child_3.rgt]
    assert_equal [13, 14], [root_2.lft, root_2.rgt]
  end

  # SQL ABSTRACTION

  test "can call included group_concat" do
    assert_nothing_raised ArgumentError do
      [:sqlite, :sqlite3, :mysql, :mysql2, :postgresql].each do |db|
        group_concat(db, 'slug')
      end
    end
  end

  test "concating a string aggregate abstracted for sqlite" do
    assert_equal "GROUP_CONCAT(slug, '/')", group_concat(:sqlite, 'slug')
  end

  test "concating a string aggregate abstracted for sqlite w/ a custom separator" do
    assert_equal "GROUP_CONCAT(slug, ',')", group_concat(:sqlite, 'slug', ',')
  end

  test "concating a string aggregate abstracted for mysql" do
    assert_equal "GROUP_CONCAT(`slug`, '/')", group_concat(:mysql, 'slug')
    assert_equal "GROUP_CONCAT(`slug`, '/')", group_concat(:mysql2, 'slug')
  end

  test "concating a string aggregate abstracted for postgres" do
    assert_equal "array_to_string(array_agg(\"slug\"), '/')", group_concat(:postgresql, 'slug')
  end
end
