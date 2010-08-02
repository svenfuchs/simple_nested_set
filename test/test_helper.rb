ENV['RAILS_ENV'] = 'test'

require 'rubygems'
require 'test/unit'
require 'fileutils'
require 'active_record'
require 'logger'
require 'pathname_local'
require 'test_declarative'
require 'database_cleaner'

$:.unshift Pathname.local('../lib').to_s
require 'simple_nested_set'

config = { 'adapter' => 'sqlite3', 'database' => ':memory:' }
ActiveRecord::Base.configurations = { 'test' =>  config }
ActiveRecord::Base.establish_connection(config)

log = '/tmp/simple_nested_set_test.log'
FileUtils.touch(log) unless File.exists?(log)
ActiveRecord::Base.logger = Logger.new(log)
Rails::LogSubscriber.add(:active_record, ActiveRecord::Railties::LogSubscriber.new)

class Test::Unit::TestCase
  def setup
    load Pathname.local('fixtures.rb')
  end

  def teardown
    DatabaseCleaner.clean
  end
end

DatabaseCleaner.strategy = :truncation
