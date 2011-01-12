ENV['RAILS_ENV'] = 'test'

require 'rubygems'
require 'test/unit'
require 'fileutils'
require 'logger'
require 'bundler/setup'
require 'erb'

require 'active_record'
require 'test_declarative'
require 'database_cleaner'
require 'ruby-debug'

# Hmmm ... without activating the gem gem_patching will fail to load the patch
# under 1.9.2 because Gem.loaded_specs is then empty. not sure what's the right
# thing to do here. Should probably be fixed in gem_patching but needs to take
# into account whatever Bundler does here.
Gem.activate('arel') if RUBY_VERSION >= '1.9'

$:.unshift File.expand_path('../../lib', __FILE__)
require 'simple_nested_set'

log = '/tmp/simple_nested_set_test.log'
FileUtils.touch(log) unless File.exists?(log)
ActiveRecord::Base.logger = Logger.new(log)

case ENV['DATABASE']
when 'postgresql'
  DB_CONFIG = {
    :adapter => 'postgresql',
    :database => 'simple_nested_set_test',
    :encoding => 'utf8',
    :username => 'simple_nested_set',
    :password => 'simple_nested_set',
    :host => '127.0.0.1',
    :port => '5432',
    :min_messages => 'notice'
  }
when 'mysql'
  DB_CONFIG = {
    :adapter => 'mysql',
    :database => 'simple_nested_set_test',
    :encoding => 'utf8',
    :username => 'simple_nested_set',
    :password => 'simple_nested_set'
  }
else # sqlite3
  DB_CONFIG = { :adapter => 'sqlite3', :database => ':memory:' }
end

puts "Running tests against #{DB_CONFIG[:adapter]}"
ActiveRecord::Base.establish_connection(DB_CONFIG)

DatabaseCleaner.strategy = :truncation

load File.expand_path('../fixtures.rb', __FILE__)

class Test::Unit::TestCase
  def teardown
    DatabaseCleaner.clean
  end
end
