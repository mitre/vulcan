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

      puts 'Syncing parallel test databases...'
      Rake::Task['parallel:prepare'].invoke
      puts 'Parallel test databases synced.'
    end
  end
end
