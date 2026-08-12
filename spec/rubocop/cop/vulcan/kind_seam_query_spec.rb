# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../../lib/rubocop/cop/vulcan/kind_seam_query'

# All fixtures below are SYNTHETIC pattern examples — they demonstrate the
# query shapes, never real file content.
RSpec.describe RuboCop::Cop::Vulcan::KindSeamQuery, :config do
  let(:msg) { described_class::MSG }

  it 'registers an offense for Rule.where(component_id:) in requirement-scoped code' do
    expect_offense(<<~RUBY)
      scope = Rule.where(component_id: component_ids)
              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY
  end

  it 'registers an offense for Rule.joins' do
    expect_offense(<<~RUBY)
      Rule.joins(:reviews).where(status: value)
      ^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY
  end

  it 'registers an offense for top-level ::Rule.where' do
    expect_offense(<<~RUBY)
      ::Rule.where(version: query)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY
  end

  it 'registers an offense for .rules traversal on a receiver' do
    expect_offense(<<~RUBY)
      component.rules.pluck(:rule_id)
      ^^^^^^^^^^^^^^^ #{msg}
    RUBY
  end

  it 'registers an offense for .rules traversal on an ivar receiver' do
    expect_offense(<<~RUBY)
      @component.rules.eager_load(:reviews)
      ^^^^^^^^^^^^^^^^ #{msg}
    RUBY
  end

  it 'does not register an offense for the kind seam accessor' do
    expect_no_offenses(<<~RUBY)
      component.requirements.pluck(:rule_id)
    RUBY
  end

  it 'does not register an offense for BaseRule scopes' do
    expect_no_offenses(<<~RUBY)
      BaseRule.live_for_components(component_ids)
    RUBY
  end

  it 'does not register an offense for SrgRule or StigRule queries' do
    expect_no_offenses(<<~RUBY)
      SrgRule.where(security_requirements_guide_id: srg_id)
      StigRule.where(srg_id: srg_id)
    RUBY
  end

  it 'registers an offense for Rule.find_by with query conditions' do
    expect_offense(<<~RUBY)
      Rule.find_by(component_id: component.id)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY
  end

  it 'registers an offense for Rule.pluck' do
    expect_offense(<<~RUBY)
      Rule.pluck(:rule_id)
      ^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY
  end

  it 'registers an offense for Rule.count' do
    expect_offense(<<~RUBY)
      total = Rule.count
              ^^^^^^^^^^ #{msg}
    RUBY
  end

  it 'registers an offense for Rule.exists?' do
    expect_offense(<<~RUBY)
      Rule.exists?(component_id: component.id)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{msg}
    RUBY
  end

  it 'does not register an offense for Rule identity lookups or construction' do
    expect_no_offenses(<<~RUBY)
      Rule.find(id)
      Rule.new(attributes)
      Rule.create!(attributes)
    RUBY
  end

  it 'does not register an offense for Rule.transaction' do
    expect_no_offenses(<<~RUBY)
      Rule.transaction do
        rule.save!
      end
    RUBY
  end

  it 'does not register an offense for the rules_count column' do
    expect_no_offenses(<<~RUBY)
      component.rules_count
    RUBY
  end

  it 'does not register an offense for a bare rules call with no receiver' do
    expect_no_offenses(<<~RUBY)
      rules.each { |rule| rule.touch }
    RUBY
  end

  it 'does not register an offense for a rules= assignment' do
    expect_no_offenses(<<~RUBY)
      self.rules = parsed_rows
    RUBY
  end

  # Enforcement-wiring correspondence: the contract is "a violation at path P
  # is flagged iff P is in scope and not allowlisted", exercised through the
  # REAL assembled configuration (require line + cop + Include + Exclude) by
  # feeding a synthetic violation to rubocop attributed to representative
  # paths. This tests the invariant, never a copy of the config lists — the
  # allowlist's one home stays .rubocop.yml, and only PERMANENT paths are
  # probed so allowlist churn needs no spec edits. A dropped Include pattern
  # or dead require line fails here (a pattern typo once left every rake
  # file dark and the cop silently inert).
  describe 'enforcement wiring through the real .rubocop.yml' do
    def offense_count_at(path)
      require 'open3'
      require 'json'
      stdout, = Open3.capture2(
        'bundle', 'exec', 'rubocop', '--stdin', path,
        '--only', 'Vulcan/KindSeamQuery', '--force-exclusion', '--format', 'json',
        stdin_data: "x = Rule.where(component_id: 1)\ny = obj.rules.to_a\n",
        chdir: File.expand_path('../../../..', __dir__)
      )
      JSON.parse(stdout).fetch('files').sum { |f| f.fetch('offenses').length }
    end

    it 'flags a violation in an app directory' do
      expect(offense_count_at('app/blueprints/wiring_probe.rb')).to eq(2)
    end

    it 'flags a violation in a rake task' do
      expect(offense_count_at('lib/tasks/wiring_probe.rake')).to eq(2)
    end

    it 'flags a violation in a seed file' do
      expect(offense_count_at('db/seeds/data/wiring_probe.rb')).to eq(2)
    end

    it 'stays quiet for an allowlisted file' do
      expect(offense_count_at('app/models/component.rb')).to eq(0)
    end

    it 'stays quiet outside the enforcement scope' do
      expect(offense_count_at('spec/models/wiring_probe_spec.rb')).to eq(0)
    end
  end
end
