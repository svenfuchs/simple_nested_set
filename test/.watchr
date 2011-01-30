# vim:ft=ruby
require 'rubygems'
require 'watchr'

all = lambda { |m|
  puts
  system "ruby test/all.rb"
}
single_test = lambda { |m|
  puts
  fn = "test/#{m[1]}_test.rb"
  if File.exist?(File.expand_path(fn))
    system "clear; ruby -Ilib -Itest #{fn}"
  else
    system "clear; ruby test/all.rb"
  end
}
quit = lambda {
  abort("\n")
}

watch '^lib/simple_nested_set/(.*).rb',  &single_test
watch '^test/(.*)_test.rb', &single_test

Signal.trap('QUIT', &all)
Signal.trap('INT', &quit)
