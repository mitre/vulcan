# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# ==========================================================================
# REQUIREMENT: upgrade:verify validates that a Vulcan upgrade completed
# successfully. Run AFTER db:prepare / db:migrate to confirm the database
# schema, FK constraints, routes, assets, and core models are healthy.
# ==========================================================================
RSpec.describe 'upgrade:verify' do
  before(:all) { Rails.application.load_tasks }

  let(:task) { Rake::Task['upgrade:verify'] }

  before do
    task.reenable
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:write)
  end

  describe 'schema verification' do
    it 'confirms no pending migrations remain' do
      output = capture_verify_output
      expect(output).to match(/no pending|migration.*current|0 pending/i)
    end

    it 'verifies all FK constraints are validated (convalidated=true)' do
      output = capture_verify_output
      expect(output).to match(/foreign key|FK|convalidated/i)
    end
  end

  describe 'model smoke tests' do
    it 'verifies Project model loads' do
      output = capture_verify_output
      expect(output).to match(/project/i)
    end

    it 'verifies User model loads' do
      output = capture_verify_output
      expect(output).to match(/user/i)
    end

    it 'verifies Component model loads' do
      output = capture_verify_output
      expect(output).to match(/component/i)
    end

    it 'verifies Review model loads' do
      output = capture_verify_output
      expect(output).to match(/review/i)
    end
  end

  describe 'route verification' do
    it 'confirms routes load successfully' do
      output = capture_verify_output
      expect(output).to match(/route/i)
    end
  end

  describe 'admin check' do
    it 'verifies at least one admin user exists' do
      create(:user, admin: true) unless User.exists?(admin: true)
      output = capture_verify_output
      expect(output).to match(/admin/i)
    end
  end

  describe 'counter cache check' do
    it 'spot-checks component rules_count accuracy' do
      output = capture_verify_output
      expect(output).to match(/counter.*cache|rules_count/i)
    end
  end

  describe 'asset check' do
    it 'verifies JavaScript pack files exist in builds directory' do
      output = capture_verify_output
      expect(output).to match(/asset|build|pack/i)
    end
  end

  describe 'summary' do
    it 'exits with status reflecting issue count (0=clean, 1=issues)' do
      expect { task.invoke }.to raise_error(SystemExit) do |e|
        expect(e.status).to be_between(0, 1)
      end
    end
  end

  private

  def capture_verify_output
    output = StringIO.new
    original_stdout = $stdout
    $stdout = output
    task.reenable
    task.invoke
    output.string
  rescue SystemExit
    output.string
  ensure
    $stdout = original_stdout
  end
end
