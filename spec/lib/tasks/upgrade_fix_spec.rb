# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'upgrade:fix' do
  before(:all) { Rails.application.load_tasks }

  let(:task) { Rake::Task['upgrade:fix'] }

  before { task.reenable }

  def capture_fix_output
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

  describe 'directory creation' do
    it 'reports on required directories' do
      output = capture_fix_output
      expect(output).to match(/director/i)
    end
  end

  describe 'pg_trgm extension' do
    it 'checks pg_trgm availability' do
      output = capture_fix_output
      expect(output).to match(/pg_trgm/)
    end
  end

  describe 'orphaned review.user_id fix' do
    it 'nullifies reviews referencing deleted users' do
      project = create(:project)
      component = create(:component, project: project)
      rule = component.rules.first
      conn = ActiveRecord::Base.connection

      # Temporarily disable FK to simulate a pre-FK database with orphaned data
      user_fk = conn.foreign_keys(:reviews).find { |fk| fk.column == 'user_id' }
      if user_fk
        conn.remove_foreign_key :reviews, column: :user_id
        conn.exec_insert(
          'INSERT INTO reviews (user_id, rule_id, action, comment, created_at, updated_at) ' \
          "VALUES (999999, #{rule.id}, 'comment', 'orphan test', NOW(), NOW())"
        )

        output = capture_fix_output
        expect(output).to match(/nullified.*user/i)

        orphan = conn.exec_query('SELECT COUNT(*) AS c FROM reviews WHERE user_id = 999999').first['c'].to_i
        expect(orphan).to eq(0)

        # Restore FK
        conn.add_foreign_key :reviews, :users, column: :user_id, on_delete: :nullify
      else
        skip 'user_id FK not present — orphan scenario not applicable'
      end
    end

    it 'reports clean when no orphans exist' do
      output = capture_fix_output
      expect(output).to match(/No orphaned review\.user_id/i)
    end
  end

  describe 'orphaned review.rule_id fix' do
    it 'deletes reviews referencing deleted rules' do
      user = create(:user)
      conn = ActiveRecord::Base.connection

      # Temporarily disable FK to simulate pre-FK database
      rule_fk = conn.foreign_keys(:reviews).find { |fk| fk.column == 'rule_id' }
      if rule_fk
        conn.remove_foreign_key :reviews, column: :rule_id
        conn.exec_insert(
          'INSERT INTO reviews (user_id, rule_id, action, comment, created_at, updated_at) ' \
          "VALUES (#{user.id}, 999999, 'comment', 'orphan test', NOW(), NOW())"
        )

        output = capture_fix_output
        expect(output).to match(/deleted.*orphaned/i)

        orphan = conn.exec_query('SELECT COUNT(*) AS c FROM reviews WHERE rule_id = 999999').first['c'].to_i
        expect(orphan).to eq(0)

        # Restore FK
        conn.add_foreign_key :reviews, :base_rules, column: :rule_id, on_delete: :restrict
      else
        skip 'rule_id FK not present — orphan scenario not applicable'
      end
    end
  end

  describe 'counter cache drift fix' do
    it 'resets drifted rules_count' do
      project = create(:project)
      component = create(:component, project: project)

      # Artificially drift the counter
      ActiveRecord::Base.connection.exec_update(
        "UPDATE components SET rules_count = 999 WHERE id = #{component.id}"
      )

      output = capture_fix_output
      expect(output).to match(/reset.*rules_count/i)
      expect(component.reload.rules_count).to eq(component.rules.count)
    end
  end

  describe 'configuration guidance' do
    it 'prints DATABASE_URL guidance when not set' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('DATABASE_URL').and_return(nil)
      allow(ENV).to receive(:[]).with('DATABASE_HOST').and_return(nil)

      output = capture_fix_output
      expect(output).to match(/DATABASE_URL|configuration/i)
    end
  end

  describe 'transaction safety' do
    it 'wraps orphan fixes in transactions' do
      expect(ActiveRecord::Base).to receive(:transaction).at_least(:once).and_call_original
      capture_fix_output
    end
  end
end
