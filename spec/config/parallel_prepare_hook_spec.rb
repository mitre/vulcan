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
end
