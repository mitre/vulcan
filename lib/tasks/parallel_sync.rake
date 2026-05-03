# frozen_string_literal: true

# Auto-sync parallel test databases after schema changes.
# Without this, db:migrate and db:reset leave parallel test DBs out of sync,
# causing flaky failures that look like test bugs but are actually schema drift.
#
# See: https://github.com/grosser/parallel_tests#setup

if defined?(ParallelTests)
  %w[db:migrate db:reset db:schema:load].each do |task_name|
    Rake::Task[task_name].enhance do
      next unless Rails.env.local?
      next if ENV['CI'] # CI shards each use a single database
      next if ENV['TEST_ENV_NUMBER'] # Already inside a parallel worker — don't recurse

      puts 'Syncing parallel test databases...'
      Rake::Task['parallel:prepare'].invoke
      # parallel:prepare's internals call ActiveRecord::Base.establish_connection
      # against the test env to set up parallel test DBs. When it returns, AR is
      # left pointed at the test connection. If a subsequent in-process task
      # (e.g. db:seed during a db:reset chain) then tries to query against the
      # dev connection, it fails with ConnectionNotDefined. Restore the original
      # env's connection so the rest of the chain works.
      ActiveRecord::Base.establish_connection(Rails.env.to_sym)
      puts 'Parallel test databases synced.'
    end
  end
end
