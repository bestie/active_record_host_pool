require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'
require 'bump/tasks'
require 'wwtd/tasks'

Rake::TestTask.new do |test|
  test.pattern = 'test/test_*.rb'
  test.verbose = true
  test.warning = false
end

task :default => 'wwtd:local'
