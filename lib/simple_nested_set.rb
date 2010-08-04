module SimpleNestedSet
  autoload :ActMacro,        'simple_nested_set/act_macro'
  autoload :ClassMethods,    'simple_nested_set/class_methods'
  autoload :InstanceMethods, 'simple_nested_set/instance_methods'
  autoload :NestedSet,       'simple_nested_set/nested_set'

  module Move
    autoload :ByAttributes,  'simple_nested_set/move/by_attributes'
    autoload :ToTarget,      'simple_nested_set/move/to_target'
    autoload :Protection,    'simple_nested_set/move/protection'
  end
end

ActiveRecord::Base.send :extend, SimpleNestedSet::ActMacro