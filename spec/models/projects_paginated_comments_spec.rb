# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENT: Project#paginated_comments decorates EVERY comment row with
# its requirement display name and component identity, regardless of
# document kind. Comments on authored SRG requirements live on the
# polymorphic commentable (the legacy rule_id column is nil) — decoration
# must key by the kind-agnostic requirement id, or SRG rows silently
# render with nil rule/component fields while STIG rows decorate fine.
RSpec.describe 'Project#paginated_comments — row decoration' do
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:project) { create(:project) }
  let_it_be(:stig_component) do
    create(:component, project: project, based_on: srg, prefix: 'STIG-00')
  end
  let_it_be(:core_srg) do
    create(:security_requirements_guide, :skip_rules, :core,
           srg_id: 'SRG-CORE-PPAG', version: 'V1R1')
  end
  let_it_be(:srg_component) do
    create(:component, :skip_rules, project: project, document_type: 'srg',
                                    based_on: core_srg, prefix: 'SRGT-00',
                                    name: 'Authored SRG', title: 'Authored SRG')
  end
  let_it_be(:authored) do
    create(:srg_rule, :authored, component: srg_component, rule_id: '000001',
                                 status: 'Applicable')
  end
  let_it_be(:commenter) { create(:user) }
  let_it_be(:srg_comment) do
    create(:review, :comment, user: commenter, rule: nil, commentable: authored,
                              section: 'fixtext', comment: 'SRG requirement comment')
  end
  let_it_be(:stig_comment) do
    create(:review, :comment, user: commenter, rule: stig_component.rules.first,
                              comment: 'STIG rule comment')
  end

  def row_for(text)
    project.paginated_comments[:rows].find { |r| r['comment'] == text }
  end

  it 'decorates an SRG comment row with its requirement display name' do
    expect(row_for('SRG requirement comment')['rule_displayed_name']).to eq('SRGT-00-000001')
  end

  it 'decorates an SRG comment row with its component identity' do
    row = row_for('SRG requirement comment')
    expect(row['component_id']).to eq(srg_component.id)
    expect(row['component_name']).to eq('Authored SRG')
  end

  it 'decorates a STIG comment row with rule display and component identity' do
    rule = stig_component.rules.first
    row = row_for('STIG rule comment')
    expect(row['rule_displayed_name']).to eq("STIG-00-#{rule.rule_id}")
    expect(row['component_id']).to eq(stig_component.id)
    expect(row['component_name']).to eq(stig_component.name)
  end
end
