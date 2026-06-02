# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'upgrade rake tasks' do
  before(:all) do
    Rails.application.load_tasks
  end

  describe 'upgrade:preflight' do
    after { Rake::Task['upgrade:preflight'].reenable }

    it 'outputs a human-readable report' do
      expect { Rake::Task['upgrade:preflight'].invoke }
        .to output(/Current version|Upgrade preflight/i).to_stdout
    end
  end

  describe 'upgrade:verify' do
    after { Rake::Task['upgrade:verify'].reenable }

    it 'verifies post-upgrade state' do
      expect { Rake::Task['upgrade:verify'].invoke }
        .to output(/verified|passed|check/i).to_stdout
    end
  end

  describe 'upgrade:fix' do
    after { Rake::Task['upgrade:fix'].reenable }

    it 'runs without error when nothing to fix' do
      expect { Rake::Task['upgrade:fix'].invoke }
        .to output(/nothing to do|applied|complete/i).to_stdout
    end
  end

  describe 'upgrade:auto' do
    after { Rake::Task['upgrade:auto'].reenable }

    it 'exits 0 silently on fresh install with no legacy DBs' do
      expect { Rake::Task['upgrade:auto'].invoke }.not_to raise_error
    end
  end
end
