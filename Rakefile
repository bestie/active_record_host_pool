require 'bundler'
Bundler::GemHelper.install_tasks :name => 'active_record_host_pool'

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end
