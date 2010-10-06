# encoding: utf-8

require File.expand_path('../test_helper', __FILE__)

class String
  def strip_leading_spaces(count)
    split("\n").map { |line| line.sub(/^\s{#{count}}/, '') }.join("\n")
  end
end

class HelpersTest < Test::Unit::TestCase
  include SimpleNestedSet
  include SqlAbstraction

  def setup
    node_1     = Node.create!(:slug => '1',     :scope_id => 1)
    node_1_1   = Node.create!(:slug => '1_1',   :scope_id => 1, :parent_id => node_1.id)
    node_1_1_1 = Node.create!(:slug => '1_1_1', :scope_id => 1, :parent_id => node_1_1.id)
    node_1_1_2 = Node.create!(:slug => '1_1_2', :scope_id => 1, :parent_id => node_1_1.id)
    node_1_2   = Node.create!(:slug => '1_2',   :scope_id => 1, :parent_id => node_1.id)
    node_1_2_1 = Node.create!(:slug => '1_2_1', :scope_id => 1, :parent_id => node_1_2.id)
    node_2     = Node.create!(:slug => '2',     :scope_id => 1)
    node_2_1   = Node.create!(:slug => '2_1',   :scope_id => 1, :parent_id => node_2.id)
    node_2_1_1 = Node.create!(:slug => '2_1_1', :scope_id => 1, :parent_id => node_2_1.id)
    node_2_1_2 = Node.create!(:slug => '2_1_2', :scope_id => 1, :parent_id => node_2_1.id)
    node_2_2   = Node.create!(:slug => '2_2',   :scope_id => 1, :parent_id => node_2.id)
    node_2_2_1 = Node.create!(:slug => '2_2_1', :scope_id => 1, :parent_id => node_2_2.id)

    unrelated_root = Node.create!(:slug => 'unrelated_root', :scope_id => 2)
  end

  test "inspect_tree (class method)" do
    expected = <<-t
      .
      └── Node id: 1
          ├── Node id: 2
          |   ├── Node id: 3
          |   └── Node id: 4
          └── Node id: 5
              └── Node id: 6
    t
    roots    = Node.roots(:scope_id => 1)
    expected = fix_ids(expected, roots.first.id - 1).strip_leading_spaces(6) # ugh
    actual = Node.first.inspect_tree

    assert_equal expected, actual.strip
  end

  test "inspect_tree (scope method)" do
    expected = <<-t
      .
      ├── Node id: 1
      |   ├── Node id: 2
      |   |   ├── Node id: 3
      |   |   └── Node id: 4
      |   └── Node id: 5
      |       └── Node id: 6
      └── Node id: 7
          ├── Node id: 8
          |   ├── Node id: 9
          |   └── Node id: 10
          └── Node id: 11
              └── Node id: 12
    t

    roots    = Node.roots(:scope_id => 1)
    expected = fix_ids(expected, roots.first.id - 1).strip_leading_spaces(6) # ugh
    actual   = roots.inspect_tree([:id])

    assert_equal expected, actual.strip
  end

  def fix_ids(expected, offset)
    expected = expected.gsub(/(\d+)/) { $1.to_i + offset }
  end
end
