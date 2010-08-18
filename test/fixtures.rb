ActiveRecord::Migration.verbose = false

class BaseNode < ActiveRecord::Base
  set_table_name 'nodes'
end

ActiveRecord::Schema.define(:version => 1) do
  create_table "node_owner", :force => true do |t|
  end

  create_table "nodes", :force => true do |t|
    t.references :node_owner
    t.string  :name
    t.string  :type
    t.integer :scope_id
    t.integer :parent_id
    t.integer :level
    t.integer :lft
    t.integer :rgt
  end
end unless BaseNode.table_exists?

class NodeOwner < BaseNode
  has_many :nodes
end

class Node < BaseNode
  acts_as_nested_set :scope => :scope_id
end

class CallbackNode < BaseNode
  acts_as_nested_set
  # TODO get callbacks working
  # before_move { |record| record.name += ' with before_move callback!' }
end

