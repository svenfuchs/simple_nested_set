require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'lib'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

namespace :test do
  desc 'run test against all supported databases'
  task :all do
    STDOUT.sync = true
    system('DATABASE=sqlite3 rake && DATABASE=postgresql rake && DATABASE=mysql rake')
    units = $?
    exit(units.exitstatus) if units.exited? and units.exitstatus != 0
  end
end

task :default => :test
