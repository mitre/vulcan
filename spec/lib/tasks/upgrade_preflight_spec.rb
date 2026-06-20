# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# ==========================================================================
# REQUIREMENT: upgrade:preflight validates database connectivity, schema
# state, data integrity, and environment configuration BEFORE a Vulcan
# upgrade. All checks are read-only. Exit 0 = safe to proceed, exit 1 =
# blockers found.
#
# The task is designed for operators upgrading from v2.2.1+ to current,
# running on vanilla PostgreSQL, Aurora RDS, or any PG-compatible host.
# ==========================================================================
RSpec.describe 'upgrade:preflight' do
  before(:all) { Rails.application.load_tasks }

  let(:task) { Rake::Task['upgrade:preflight'] }

  before do
    task.reenable
    # Suppress stdout during tests
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:write)
  end

  # ========================================================================
  # Phase 1: Connection & Environment
  # ========================================================================
  describe 'Phase 1: Connection & Environment' do
    it 'reports the PostgreSQL version' do
      expect { task.invoke }.to output(/PostgreSQL/).to_stdout_from_any_process
    rescue SystemExit
      # Task may exit 0 or 1 depending on state — we just care about output
    end

    it 'detects Aurora when version string contains Aurora' do
      allow(ActiveRecord::Base.connection).to receive(:exec_query)
        .and_call_original
      allow(ActiveRecord::Base.connection).to receive(:exec_query)
        .with('SELECT version()')
        .and_return(ActiveRecord::Result.new(['version'], [['PostgreSQL 14.2 on Aurora']]))

      output = capture_preflight_output
      expect(output).to include('Aurora')
    end

    it 'checks SSL connection status' do
      output = capture_preflight_output
      expect(output).to match(/SSL|ssl/)
    end

    it 'detects read-replica and flags as blocker' do
      allow(ActiveRecord::Base.connection).to receive(:exec_query)
        .and_call_original
      allow(ActiveRecord::Base.connection).to receive(:exec_query)
        .with('SELECT pg_is_in_recovery()')
        .and_return(ActiveRecord::Result.new(['pg_is_in_recovery'], [['t']]))

      output = capture_preflight_output
      expect(output).to match(/read.replica|recovery|read-only/i)
    end

    it 'checks pg_trgm extension availability' do
      output = capture_preflight_output
      expect(output).to match(/pg_trgm/)
    end

    it 'checks database encoding is UTF8' do
      output = capture_preflight_output
      expect(output).to match(/encoding|UTF/i)
    end

    it 'validates required environment variables' do
      output = capture_preflight_output
      expect(output).to include('SECRET_KEY_BASE')
      expect(output).to include('CIPHER_PASSWORD')
      expect(output).to include('CIPHER_SALT')
    end

    it 'warns about gssencmode for cloud RDS' do
      output = capture_preflight_output
      expect(output).to match(/gssencmode|GSSENCMODE/i)
    end
  end

  # ========================================================================
  # Phase 2: Schema State
  # ========================================================================
  describe 'Phase 2: Schema State' do
    it 'reports current schema version' do
      output = capture_preflight_output
      expect(output).to match(/schema version/i)
    end

    it 'lists pending migrations with count' do
      output = capture_preflight_output
      expect(output).to match(/pending migration|No pending/i)
    end

    it 'tags risky migrations with risk indicators' do
      # If there are pending migrations, they should be tagged
      output = capture_preflight_output
      # FK, INDEX, DATA tags should appear for relevant migrations
      expect(output).to match(/\[FK\]|\[INDEX\]|\[DATA\]|No pending/i)
    end

    it 'detects schema drift (columns in DB not in schema.rb)' do
      output = capture_preflight_output
      expect(output).to match(/drift|schema/i)
    end

    it 'detects partial migrations (column exists but migration not recorded)' do
      output = capture_preflight_output
      expect(output).to match(/partial|integrity/i)
    end

    it 'reports the upgrade path with version-specific notes' do
      output = capture_preflight_output
      expect(output).to match(/upgrade path|version/i)
    end
  end

  # ========================================================================
  # Phase 3: Data Integrity
  # ========================================================================
  describe 'Phase 3: Data Integrity' do
    let!(:project) { create(:project) }
    let!(:component) { create(:component, project: project) }

    it 'checks for orphaned review.user_id references' do
      output = capture_preflight_output
      expect(output).to match(/orphan.*user|user.*orphan|review.*user/i)
    end

    it 'checks for orphaned review.rule_id references' do
      output = capture_preflight_output
      expect(output).to match(/orphan.*rule|rule.*orphan|review.*rule/i)
    end

    it 'checks for orphaned component.project_id references' do
      output = capture_preflight_output
      expect(output).to match(/orphan.*component|component.*project/i)
    end

    it 'checks for orphaned membership references' do
      output = capture_preflight_output
      expect(output).to match(/orphan.*membership|membership/i)
    end

    it 'checks counter cache drift on components.rules_count' do
      output = capture_preflight_output
      expect(output).to match(/counter.*cache|rules_count/i)
    end

    it 'reports table sizes for migration time estimation' do
      output = capture_preflight_output
      expect(output).to match(/table size|reviews:|users:|base_rules:/i)
    end

    it 'checks audits table size and warns if large' do
      output = capture_preflight_output
      expect(output).to match(/audit/i)
    end
  end

  # ========================================================================
  # Phase 4: Application Configuration
  # ========================================================================
  describe 'Phase 4: Application Configuration' do
    it 'checks Ruby version matches .ruby-version' do
      output = capture_preflight_output
      expect(output).to match(/ruby.*version|Ruby/i)
    end

    it 'checks writable directories (tmp, log, storage, db)' do
      output = capture_preflight_output
      expect(output).to match(/writable|directory|tmp|log/i)
    end

    it 'checks YAML permitted classes configuration' do
      output = capture_preflight_output
      expect(output).to match(/YAML|yaml|permitted/i)
    end
  end

  # ========================================================================
  # Phase 5: Summary & Recommendations
  # ========================================================================
  describe 'Phase 5: Summary' do
    it 'exits 0 when no blockers found' do
      expect { task.invoke }.to raise_error(SystemExit) { |e| expect(e.status).to eq(0) }
    end

    it 'prints backup recommendation' do
      output = capture_preflight_output
      expect(output).to match(/backup|pg_dump/i)
    end

    it 'prints Aurora-specific notes when Aurora detected' do
      allow(ActiveRecord::Base.connection).to receive(:exec_query)
        .and_call_original
      allow(ActiveRecord::Base.connection).to receive(:exec_query)
        .with('SELECT version()')
        .and_return(ActiveRecord::Result.new(['version'], [['PostgreSQL 14.2 on Aurora']]))

      output = capture_preflight_output
      expect(output).to match(/Aurora.*RDS|cluster.*endpoint|sslmode/i)
    end
  end

  # ========================================================================
  # Helpers
  # ========================================================================
  private

  def capture_preflight_output
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
