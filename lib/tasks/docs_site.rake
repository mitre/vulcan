# frozen_string_literal: true

namespace :docs do
  desc 'Build the documentation site the application serves'
  task build: :environment do
    DocsSite.build!
  end
end

# The image build already runs asset precompilation. Attaching here means the
# documentation site is produced by that same step, so a released image cannot
# be built without it.
Rake::Task['assets:precompile'].enhance(['docs:build']) if Rake::Task.task_defined?('assets:precompile')
