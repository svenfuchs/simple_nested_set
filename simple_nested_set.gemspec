# encoding: utf-8

$:.unshift File.expand_path('../lib', __FILE__)
require 'simple_nested_set/version'

Gem::Specification.new do |s|
  s.name         = "simple_nested_set"
  s.version      = SimpleNestedSet::VERSION
  s.authors      = ["Sven Fuchs"]
  s.email        = "svenfuchs@artweb-design.de"
  s.homepage     = "http://github.com/svenfuchs/simple_nested_set"
  s.summary      = "[summary]"
  s.description  = "[description]"

  s.files        = `git ls-files {app,lib}`.split("\n")
  s.platform     = Gem::Platform::RUBY
  s.require_path = 'lib'
  s.rubyforge_project = '[none]'
  s.required_rubygems_version = '>= 1.3.6'
end
