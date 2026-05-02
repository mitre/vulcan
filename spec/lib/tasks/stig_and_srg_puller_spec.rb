# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# PR-717 review remediation .vb4 — request_uuid producer side. The
# stig_and_srg_puller:pull task is a non-HTTP code path. The
# audit-compliance review flagged that any audit row emitted during the
# task would land with a distinct SecureRandom.uuid (via the .14r
# consumer fallback), so a forensic operator running
# AuditEventBundle.bundled_with(audit_id) on a row from the rake
# invocation could not reconstruct the entire pull as one logical
# operation.
#
# The Stig / SecurityRequirementsGuide / StigRule / SrgRule models are
# not vulcan_audited TODAY — wrapping save_data in the correlation
# scope is preemptive defense so that the moment any model touched
# during pull starts emitting audits (or one of these models becomes
# audited), the forensic invariant holds without further refactoring.
RSpec.describe 'stig_and_srg_puller:save_data (PR-717 .vb4 wrap)' do
  before(:all) { Rails.application.load_tasks }

  before do
    Audited.store.delete(:current_request_uuid)
    # Skip the network-fetching prerequisite tasks; supply @process_data
    # directly via instance_variable_set on the rake context.
    Rake::Task['stig_and_srg_puller:save_data'].clear_prerequisites
  end

  after do
    Audited.store.delete(:current_request_uuid)
    Rake::Task['stig_and_srg_puller:save_data'].reenable
  end

  it 'wraps the task body in VulcanAudit.with_correlation_scope' do
    # The body short-circuits when @process_data is empty (each loop is
    # a no-op), so we don't need real STIG/SRG XML to verify the wrap.
    captured_uuid = nil
    allow(VulcanAudit).to receive(:with_correlation_scope).and_wrap_original do |orig, **kwargs, &block|
      orig.call(**kwargs) do |uuid|
        captured_uuid = uuid
        block.call(uuid)
      end
    end

    TOPLEVEL_BINDING.eval('@process_data = []')
    Rake::Task['stig_and_srg_puller:save_data'].execute

    expect(VulcanAudit).to have_received(:with_correlation_scope).at_least(:once)
    expect(captured_uuid).to match(/\A[0-9a-f-]{36}\z/)
  end

  it 'restores Audited.store[:current_request_uuid] to its prior value after the task body' do
    Audited.store[:current_request_uuid] = 'outer-uuid'
    TOPLEVEL_BINDING.eval('@process_data = []')
    Rake::Task['stig_and_srg_puller:save_data'].execute
    expect(Audited.store[:current_request_uuid]).to eq('outer-uuid')
  end
end
