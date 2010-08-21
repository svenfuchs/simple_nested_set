require 'active_record'

module SimpleNestedSet
  ATTRIBUTES = [:parent, :parent_id, :left_id, :right_id, :lft, :rgt, :level, :path]

  autoload :ActMacro,        'simple_nested_set/act_macro'
  autoload :ClassMethods,    'simple_nested_set/class_methods'
  autoload :InstanceMethods, 'simple_nested_set/instance_methods'
  autoload :NestedSet,       'simple_nested_set/nested_set'
  autoload :SqlAbstraction,  'simple_nested_set/sql_abstraction.rb'

  module Move
    autoload :ByAttributes,  'simple_nested_set/move/by_attributes'
    autoload :ToTarget,      'simple_nested_set/move/to_target'
    autoload :Protection,    'simple_nested_set/move/protection'
    autoload :Impossible,    'simple_nested_set/move/protection'
    autoload :Inconsistent,  'simple_nested_set/move/protection'
  end

  module Rebuild
    autoload :FromPaths,     'simple_nested_set/rebuild/from_paths'
  end
end

ActiveRecord::Base.send :extend, SimpleNestedSet::ActMacro
