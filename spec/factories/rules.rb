# frozen_string_literal: true

FactoryBot.define do
  factory :rule do
    # Rules require a component and srg_rule.
    # The component's based_on SRG should have an srg_rule we can use.
    transient do
      use_component { nil }
    end

    component { use_component || create(:component) }

    # Get an srg_rule from the component's SRG
    srg_rule do
      srg = component.based_on
      srg.srg_rules.first || create(:srg_rule, security_requirements_guide: srg)
    end

    # rule_id must be unique within component scope
    # Use FACTORY- prefix to avoid conflicts with SRG-imported rules
    sequence(:rule_id) { |n| "FACTORY-#{n.to_s.rjust(6, '0')}" }
    title { 'Default Rule Title' }
    status { 'Not Yet Determined' }
    rule_severity { 'medium' }
    fixtext { 'Default fix text for this rule.' }
    vendor_comments { nil }
    status_justification { nil }
    artifact_description { nil }

    trait :with_title do
      transient do
        custom_title { 'Custom Title' }
      end

      title { custom_title }
    end

    trait :with_fixtext do
      transient do
        custom_fixtext { 'Custom fix text' }
      end

      fixtext { custom_fixtext }
    end

    trait :kubernetes do
      title { 'Kubernetes API Server Configuration' }
      fixtext { 'Configure the Kubernetes API server to enforce TLS encryption.' }
    end

    trait :approved do
      status { 'Applicable - Configurable' }
    end

    trait :not_applicable do
      status { 'Not Applicable' }
      status_justification { 'This control does not apply to this system.' }
    end
  end

  factory :srg_rule do
    security_requirements_guide

    sequence(:rule_id) { |n| "SV-#{200_000 + n}" }
    title { 'SRG Rule Title' }
    version { 'V1R1' }
    rule_severity { 'medium' }
  end
end
