# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'parallel test database sync hook' do
  # REQUIREMENT: After db:migrate or db:reset, parallel test databases must be
  # synced automatically. Developers should not need to remember to run
  # parallel:prepare manually — forgetting causes flaky test failures.

  it 'a rake task hooks parallel:prepare after db:migrate' do
    task_file = Rails.root.join('lib/tasks/parallel_sync.rake')
    expect(task_file).to exist, 'lib/tasks/parallel_sync.rake must exist to auto-sync parallel test DBs'

    content = task_file.read
    expect(content).to match(/db:migrate.*parallel:prepare|enhance.*parallel/m),
                       'Must hook parallel:prepare after db:migrate'
  end

  it 'bin/parallel_rspec binstub caps processors to prevent flaky failures' do
    binstub = Rails.root.join('bin/parallel_rspec')
    expect(binstub).to exist, 'bin/parallel_rspec must exist as the standard way to run parallel tests'

    content = binstub.read
    expect(content).to match(/PARALLEL_TEST_PROCESSORS/),
                       'binstub must set PARALLEL_TEST_PROCESSORS to cap CPU usage'
  end
end
