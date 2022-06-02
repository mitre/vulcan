# frozen_string_literal: true

FactoryBot.define do
  factory :srg_rule do
    security_requirements_guide { create(:security_requirements_guide) }

    status { 'Not Yet Determined' }
    rule_id { generate(:rule_id) }
    rule_severity { 'medium' }
    rule_weight { '10.0' }
    version { 'SRG-OS-000001-GPOS-00001' }
    title { '...' }
    ident { 'CCI-000015' }
    fixtext { '...' }
    fixtext_fixref { 'F-3716r557030_fix' }
    fix_id { 'F-3716r557030_fix' }
    changes_requested { false }
  end
end
