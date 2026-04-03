# frozen_string_literal: true

# Rake task wrapper for parallel_rspec with sane defaults.
# Caps at 8 processors to prevent CPU contention flaky failures on 10-core machines.
# See: https://makandracards.com/makandra/495461
#
# Usage:
#   rake spec:parallel              # Run full suite (8 processors)
#   rake spec:parallel[spec/models] # Run specific directory
#
if defined?(ParallelTests)
  namespace :spec do
    desc 'Run RSpec in parallel (8 processors, prevents flaky CPU contention)'
    task :parallel, [:path] do |_t, args| # rubocop:disable Rails/RakeEnvironment
      path = args[:path] || 'spec/'
      processors = ENV.fetch('PARALLEL_TEST_PROCESSORS', '8')
      sh "PARALLEL_TEST_PROCESSORS=#{processors} bundle exec parallel_rspec #{path}"
    end
  end
end
