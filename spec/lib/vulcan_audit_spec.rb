# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VulcanAudit do
  describe '#find_and_save_associated_rule' do
    # Regression: previously used `rule.present? & rule.component.present?` (bitwise `&`)
    # which does NOT short-circuit. When rule was nil, evaluating `rule.component`
    # raised NoMethodError. Fixed to use `&&` + early return.

    # Regression: the critical bug is that `rule.present? & rule.component.present?`
    # evaluates `rule.component` even when rule is nil, raising NoMethodError.
    # The fix is to use `&&` (short-circuit). We test the nil path explicitly.

    it 'does not raise NoMethodError when the rule has been deleted (nil rule)' do
      audit = VulcanAudit.new(
        auditable_type: 'BaseRule',
        associated_type: 'Component',
        auditable_id: 999_999_999,
        action: 'update'
      )
      expect { audit.send(:find_and_save_associated_rule) }.not_to raise_error
      expect(audit.audited_username).to be_nil
    end

    it 'skips for destroy actions' do
      audit = VulcanAudit.new(
        auditable_type: 'BaseRule',
        associated_type: 'Component',
        auditable_id: 999_999_999,
        action: 'destroy'
      )
      audit.send(:find_and_save_associated_rule)
      expect(audit.audited_username).to be_nil
    end

    it 'skips for non-BaseRule auditables' do
      audit = VulcanAudit.new(
        auditable_type: 'User',
        associated_type: 'Component',
        auditable_id: 1,
        action: 'update'
      )
      expect { audit.send(:find_and_save_associated_rule) }.not_to raise_error
    end
  end

  # request_uuid correlation works for
  # HTTP-driven audits (Audited::Sweeper Rack middleware auto-populates).
  # Pre-fix, audits created outside an HTTP request (rake tasks, seeds,
  # ActiveJob workers, after-commit hooks dispatched after request ends)
  # had request_uuid NULL — AuditEventBundle.bundled_with returns just
  # the trigger row in that case, breaking forensic correlation across
  # any non-HTTP-driven multi-row operation.
  #
  # Fix: VulcanAudit before_create reads Audited.store[:current_request_uuid]
  # first (job/rake middleware sets it), falls back to SecureRandom.uuid
  # if unset. Result: every audit row has a request_uuid; rows from one
  # logical operation share one UUID.
  describe 'request_uuid backfill for non-HTTP audits' do
    let(:user) { create(:user) }
    let(:project) { Project.create!(name: 'pr717-14r') }
    let(:component) do
      Component.create!(project: project, name: '14r component',
                        title: '14r component', version: 'v1', prefix: 'PR14-01',
                        based_on: SecurityRequirementsGuide.first || create(:security_requirements_guide))
    end

    before do
      Audited.store[:audited_user] = user
      Audited.store.delete(:current_request_uuid)
    end

    it 'populates request_uuid via SecureRandom when no store key set (orphan path)' do
      audit = component.audits.create!(action: 'sample', comment: 'orphan path test')
      expect(audit.request_uuid).to be_present
      expect(audit.request_uuid).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'reuses Audited.store[:current_request_uuid] when set (job/rake middleware path)' do
      Audited.store[:current_request_uuid] = '00000000-0000-4000-8000-aaaaaaaaaaaa'
      audit = component.audits.create!(action: 'sample', comment: 'middleware path test')
      expect(audit.request_uuid).to eq('00000000-0000-4000-8000-aaaaaaaaaaaa')
    end

    it 'shares one request_uuid across multiple audits in the same logical operation' do
      Audited.store[:current_request_uuid] = '11111111-1111-4111-8111-bbbbbbbbbbbb'
      a = component.audits.create!(action: 'sample-1', comment: 'op-row-1')
      b = component.audits.create!(action: 'sample-2', comment: 'op-row-2')
      expect(a.request_uuid).to eq(b.request_uuid)
    end

    it 'gives different orphan-path audits distinct request_uuids' do
      Audited.store.delete(:current_request_uuid)
      a = component.audits.create!(action: 'sample-1', comment: 'orphan-1')
      Audited.store.delete(:current_request_uuid) # ensure fresh per call
      b = component.audits.create!(action: 'sample-2', comment: 'orphan-2')
      expect(a.request_uuid).not_to eq(b.request_uuid)
    end

    it 'does not overwrite a request_uuid set by Audited::Sweeper (HTTP path)' do
      # When the audited gem's sweeper has already populated request_uuid
      # (typical HTTP-request path), our before_create must not stomp it.
      audit = component.audits.build(action: 'sample', comment: 'preserve-test')
      audit.request_uuid = '22222222-2222-4222-8222-cccccccccccc'
      audit.save!
      expect(audit.reload.request_uuid).to eq('22222222-2222-4222-8222-cccccccccccc')
    end
  end

  # request_uuid PRODUCER side. The .14r
  # consumer hook (ensure_request_uuid before_create) reads
  # Audited.store[:current_request_uuid] and falls back to SecureRandom
  # if unset. The producer side wraps a bulk audit-emitting code path
  # (rake tasks, importers, future ActiveJob workers) in a scope that
  # sets the same UUID for every audit emitted during the block.
  #
  # Snapshot+restore (not set+delete) so it nests correctly under any
  # outer scope that also sets the value (e.g. an HTTP request that
  # invokes a service object).
  describe '.with_correlation_scope' do
    let(:user) { create(:user) }
    let(:project) { Project.create!(name: 'pr717-vb4') }
    let(:component) do
      Component.create!(project: project, name: 'vb4 component',
                        title: 'vb4 component', version: 'v1', prefix: 'PRVB-01',
                        based_on: SecurityRequirementsGuide.first || create(:security_requirements_guide))
    end

    before do
      Audited.store[:audited_user] = user
      Audited.store.delete(:current_request_uuid)
    end

    after { Audited.store.delete(:current_request_uuid) }

    it 'sets a request_uuid for the duration of the block' do
      observed = nil
      described_class.with_correlation_scope do
        observed = Audited.store[:current_request_uuid]
      end
      expect(observed).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'yields the uuid to the block' do
      yielded = nil
      described_class.with_correlation_scope { |uuid| yielded = uuid }
      expect(yielded).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'restores nil when no prior value was set' do
      described_class.with_correlation_scope { :noop }
      expect(Audited.store[:current_request_uuid]).to be_nil
    end

    it 'restores the prior value when one was already set (nesting)' do
      Audited.store[:current_request_uuid] = 'outer-uuid'
      described_class.with_correlation_scope { :noop }
      expect(Audited.store[:current_request_uuid]).to eq('outer-uuid')
    end

    it 'restores the prior value even if the block raises' do
      Audited.store[:current_request_uuid] = 'outer-uuid'
      expect { described_class.with_correlation_scope { raise StandardError, 'boom' } }.to raise_error('boom')
      expect(Audited.store[:current_request_uuid]).to eq('outer-uuid')
    end

    it 'accepts an explicit uuid: argument' do
      described_class.with_correlation_scope(uuid: 'fixed-uuid') do
        expect(Audited.store[:current_request_uuid]).to eq('fixed-uuid')
      end
    end

    it 'shares one request_uuid across multiple audits emitted inside the block' do
      uuids = nil
      described_class.with_correlation_scope do
        component.audits.create!(action: 'sample-1', comment: 'row-1')
        component.audits.create!(action: 'sample-2', comment: 'row-2')
        uuids = component.audits.where(action: %w[sample-1 sample-2]).pluck(:request_uuid)
      end
      expect(uuids.uniq.size).to eq(1)
      expect(uuids.first).to match(/\A[0-9a-f-]{36}\z/)
    end
  end
end
