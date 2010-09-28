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


  # SCOPES

  test "Node::NestedSet.scope(:scope_id => 1) scopes to the given scope" do
    assert_equal nodes, Node::NestedSet.scope(:scope_id => 1)
  end

  # TODO
  #
  # # CALLBACKS
  #
  # test "before_move callback gets called" do
  #   assert_equal 'foo with before_move callback!', CallbackNode.create!(:name => 'foo').name
  # end


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

  test "node.level returns the node's path" do
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


  # MOVING

  test "node.move_path moves the node to the given path (w/ a root path)" do
    child_1.move_to_path(root.path)
    assert child_1.root?
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

  test "node.update_attributes(:right_id => '') makes the node the rightmost amongst its siblings" do
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

  # REBUILD NESTED SET

  test "rebuild_from_path" do
    child_2_2 = Node.create!(:slug => 'child_2_2', :scope_id => 1, :parent_id => child_2.id)
    child_3   = Node.create!(:slug => 'child_3',   :scope_id => 1, :parent_id => root.id)
    root_2    = Node.create!(:slug => 'root_2',   :scope_id => 1)

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

  # SQL ABSTRACTION

  test "can call included group_concat" do
    assert_nothing_raised ArgumentError do
      [:sqlite, :sqlite3, :mysql, :postgresql].each do |db|
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
  end

  test "concating a string aggregate abstracted for postgres" do
    assert_equal "array_to_string(array_agg(\"slug\"), '/')", group_concat(:postgresql, 'slug')
  end
end
