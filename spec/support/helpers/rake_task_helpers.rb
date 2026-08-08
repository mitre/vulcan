# frozen_string_literal: true

# Loads the application's Rake tasks exactly once per test-suite run.
#
# Several task specs called Rails.application.load_tasks in before(:all).
# Each call re-executes every .rake file body, which re-defines top-level
# constants (e.g. BackupAuditor::* in seed_backup.rake, railties'
# STATS_DIRECTORIES) and floods the suite log with "already initialized
# constant" warnings. Loading exactly once eliminates the warnings; the
# tasks are static, so re-loading was never needed.
module RakeTaskHelpers
  @loaded = false

  class << self
    attr_accessor :loaded
  end

  def load_rake_tasks
    return if RakeTaskHelpers.loaded

    Rails.application.load_tasks
    RakeTaskHelpers.loaded = true
  end
end

RSpec.configure do |config|
  config.include RakeTaskHelpers
end
