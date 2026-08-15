# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: two truly concurrent executes into the same target
# component must each land on their own number — the target-component
# row lock serializes number assignment, so neither request fails.
#
# The true two-connection race lives in its own file: let_it_be data in
# the main executor spec sits in an open before_all transaction on the
# main connection, so a threaded example there would build records its
# threads can never see. The truncation tag (the system-spec mechanism)
# cleans up this file's committed rows.
RSpec.describe RelocationExecutor, :truncation do
  # Class-level, not the truncation hook alone: the hook runs after
  # rspec-rails has already opened the example's fixture transaction and
  # pinned the connection, which hands every thread the SAME connection
  # and quietly serializes the race.
  self.use_transactional_tests = false

  it 'two concurrent executes into the same target each land on their own number' do
    core = create(:security_requirements_guide, :core, :skip_rules,
                  srg_id: 'SRG-CORE-EXEC-CC', version: 'V1R1')
    user = create(:user)
    project = create(:project)
    component = lambda do |prefix|
      create(:component, :skip_rules, project: project, document_type: 'srg',
                                      based_on: core, prefix: prefix)
    end
    target = component.call('CCTG-00')
    relocations = %w[CCSA-00 CCSB-00].map do |prefix|
      source = create(:srg_rule, :authored, component: component.call(prefix), rule_id: '500001')
      RequirementRelocation.create!(source_rule: source, target_technology_token: 'CCTG',
                                    requested_by: user)
    end

    # Both threads hold their computed landing number before either saves —
    # the deterministic form of the race. With the component row locked, the
    # second thread cannot reach this point until the first commits, so the
    # first simply times out the wait and proceeds.
    # Singleton methods, not rspec-mocks stubs: the mock proxy dispatches
    # under a global mutex, so a latch inside a stub serializes the very
    # race this example exists to produce.
    latch = Concurrent::CountDownLatch.new(2)
    targets = relocations.map do
      Component.find(target.id).tap do |instance|
        original = instance.method(:largest_rule_id)
        instance.define_singleton_method(:largest_rule_id) do
          value = original.call
          latch.count_down
          latch.wait(1)
          value
        end
      end
    end

    # Ready-latch: both threads hold a live connection before either starts,
    # so thread startup cost cannot serialize the race by accident.
    ready = Concurrent::CountDownLatch.new(2)
    errors = Concurrent::Array.new
    threads = relocations.zip(targets).map do |relocation, thread_target|
      Thread.new do
        ApplicationRecord.connection_pool.with_connection do |connection|
          connection.execute('SELECT 1')
          ready.count_down
          ready.wait(5)
          described_class.new(relocation, target_component: thread_target,
                                          accepted_by: user).execute!
        rescue StandardError => e
          errors << e
        end
      end
    end
    threads.each(&:join)

    expect(errors).to be_empty
    landed = SrgRule.where(component_id: target.id).order(:rule_id).pluck(:rule_id)
    expect(landed).to eq(%w[000001 000002])
    expect(relocations.each(&:reload).map(&:executed_at)).to all(be_present)
  end
end
