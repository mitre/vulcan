FactoryBot.define do
  factory :srg_control_1, class: SrgControl do
    control_id 'v-111111'
    severity 'high'
    title 'MyString'
    description 'MyString1'
    ruleId 'v-223445'
    fixid '289424'
    fixtext 'do something'
    checktext 'check something'
    srg_title_id 'SRG_ID_000032'
  end

  factory :srg_control_2, class: SrgControl do
    control_id 'v-222222'
    severity 'medium'
    title 'MyString2'
    description 'MyString2'
    ruleId 'v-223445'
    fixid '289424'
    fixtext 'do something'
    checktext 'check something'
    srg_title_id 'SRG_ID_000032'
  end

  factory :invalid_srg_control, class: SrgControl do
    control_id nil
    severity 'high'
    title 'MyString'
    description nil
    ruleId 'v-223445'
    fixid '289424'
    fixtext 'do something'
    checktext 'check something'
    srg_title_id 'SRG_ID_000032'
  end
end
