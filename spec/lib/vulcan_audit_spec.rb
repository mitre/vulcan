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
end
