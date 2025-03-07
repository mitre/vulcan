FactoryBot.define do
  factory :base_rule do
    rule_id { 'rule-1' }
    status { 'Not Reviewed' }
    rule_severity { 'medium' }
    rule_weight { 10.0 }
    version { '1.0' }
    title { 'Sample Rule' }
    ident { 'CCI-000001' }
    legacy_ids { '' }
    ident_system { 'CCI' }
    fixtext { 'Sample Fix Text' }
    fixtext_fixref { 'fixref' }
    fix_id { 'fix-1' }

    after(:build) do |base_rule|
      base_rule.rule_descriptions << FactoryBot.build(:rule_description, base_rule: base_rule)
      base_rule.disa_rule_descriptions << FactoryBot.build(:disa_rule_description, base_rule: base_rule)
      base_rule.checks << FactoryBot.build(:check, base_rule: base_rule)
      base_rule.references << FactoryBot.build(:reference, base_rule: base_rule)
    end
  end
end
