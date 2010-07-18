ActiveRecord::Migration.verbose = false

class Base < ActiveRecord::Base
  set_table_name 'nodes'
end

ActiveRecord::Schema.define(:version => 1) do
  create_table "nodes", :force => true do |t|
    t.string  :name
    t.string  :type
    t.integer :lft
    t.integer :rgt
    t.integer :scope_id
    t.integer :parent_id
  end
end unless Base.table_exists?

class Node < Base
  acts_as_nested_set :scope => :scope_id
end

class CallbackNode < Base
  acts_as_nested_set
  # TODO get callbacks working
  # before_move { |record| record.name += ' with before_move callback!' }
end

root      = Node.create!(:name => 'root',      :scope_id => 1, :lft => 1, :rgt => 8)
child_1   = Node.create!(:name => 'child_1',   :scope_id => 1, :lft => 2, :rgt => 3, :parent => root)
child_2   = Node.create!(:name => 'child_2',   :scope_id => 1, :lft => 4, :rgt => 7, :parent => root)
child_2_1 = Node.create!(:name => 'child_2_1', :scope_id => 1, :lft => 5, :rgt => 6, :parent => child_2)

unrelated_root = Node.create!(:name => 'child_2_1', :scope_id => 2, :lft => 1, :rgt => 2)