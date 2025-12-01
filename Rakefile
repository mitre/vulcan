# frozen_string_literal: true

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks

# =============================================================================
# Default Test Task Configuration
# =============================================================================
# Override default test task to use parallel_tests for faster execution
# Run with: rake test (or just rake)
# For single-threaded: bundle exec rspec
# =============================================================================

if defined?(ParallelTests)
  # Remove the default Rails test task
  Rake::Task['test'].clear if Rake::Task.task_defined?('test')

  desc 'Run tests in parallel (default)'
  task test: :environment do
    sh 'bundle exec parallel_rspec spec/'
  end

  namespace :test do
    desc 'Run tests in parallel (alias for rake test)'
    task parallel: :environment do
      sh 'bundle exec parallel_rspec spec/'
    end

    desc 'Run tests single-threaded (slower, for debugging)'
    task serial: :environment do
      sh 'bundle exec rspec'
    end

    desc 'Prepare parallel test databases'
    task prepare: :environment do
      sh 'bundle exec rake parallel:create parallel:prepare'
    end

    desc 'Run specific test file in parallel'
    task :file, [:path] => :environment do |_t, args|
      if args[:path]
        sh "bundle exec rspec #{args[:path]}"
      else
        puts 'Usage: rake test:file[spec/path/to/spec.rb]'
      end
    end
  end

  # Also override spec task if it exists
  Rake::Task['spec'].clear if Rake::Task.task_defined?('spec')

  desc 'Run specs in parallel (alias for rake test)'
  task spec: :test
end

# =============================================================================
# Full Test Suite (Frontend + Backend)
# =============================================================================

desc 'Run all tests (frontend + backend in parallel)'
task test_all: :environment do
  puts '=== Running Frontend Tests (Vitest) ==='
  sh 'pnpm vitest run'
  puts ''
  puts '=== Running Backend Tests (RSpec Parallel) ==='
  sh 'bundle exec parallel_rspec spec/'
end

desc 'Run linters (RuboCop + ESLint)'
task lint: :environment do
  puts '=== Running RuboCop ==='
  sh 'bundle exec rubocop'
  puts ''
  puts '=== Running ESLint ==='
  sh 'pnpm lint:ci'
end

desc 'Run security checks (Brakeman + bundler-audit)'
task security: :environment do
  puts '=== Running Brakeman ==='
  sh 'bundle exec brakeman -q'
  puts ''
  puts '=== Running bundler-audit ==='
  sh 'bundle exec bundler-audit check --update'
end

# Make test the default task
task default: :test
