ENV['RAILS_ENV'] = 'test'

require 'rubygems'
require 'test/unit'
require 'fileutils'
require 'active_record'
require 'logger'
require 'pathname_local'
require 'test_declarative'
require 'database_cleaner'
require 'ruby-debug'

$:.unshift Pathname.local('../lib').to_s
require 'simple_nested_set'

log = '/tmp/simple_nested_set_test.log'
FileUtils.touch(log) unless File.exists?(log)
ActiveRecord::Base.logger = Logger.new(log)
ActiveRecord::LogSubscriber.attach_to(:active_record)
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

DatabaseCleaner.strategy = :truncation

class Test::Unit::TestCase
  def setup
    load Pathname.local('fixtures.rb')
  end

  def teardown
    DatabaseCleaner.clean
  end
end