require 'rspec/core/rake_task'

# Define the "spec" task, at task load time rather than inside another task
RSpec::Core::RakeTask.new(:spec)

namespace :ci do
  desc "Run CI Smoke Tests"

  task :test do
    ENV['RUN_ALL_TESTS'] = 'true'
    Rake::Task['spec'].invoke

    puts "Build Passed"
  end
end

desc "run 'rake ci' from Jenkins"
task ci: 'ci:test'
