# frozen_string_literal: true

require 'rails_helper'

# Verifies ProjectBlueprint :show + nested ComponentBlueprint :index render
# the pending_comment_count fields when controllers pass the
# `:pending_comment_counts` option (PR #717 follow-on, project-detail
# + component-card badges).
RSpec.describe 'ProjectBlueprint pending_comment_count' do
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component_a) { create(:component, project: project, based_on: srg) }
  let_it_be(:component_b) { create(:component, project: project, based_on: srg) }

  let(:counts) { { component_a.id => 3, component_b.id => 2 } }
  let(:json) do
    ProjectBlueprint.render_as_hash(
      project,
      view: :show,
      pending_comment_counts: counts
    )
  end

  it 'exposes the project-level pending_comment_count as the sum across components' do
    expect(json[:pending_comment_count]).to eq(5)
  end

  it 'propagates per-component counts through the components association' do
    components = json[:components].index_by { |c| c[:id] }
    expect(components[component_a.id][:pending_comment_count]).to eq(3)
    expect(components[component_b.id][:pending_comment_count]).to eq(2)
  end

  it 'defaults to 0 for components missing from the counts hash' do
    json_no_counts = ProjectBlueprint.render_as_hash(project, view: :show)
    expect(json_no_counts[:pending_comment_count]).to eq(0)
    json_no_counts[:components].each do |c|
      expect(c[:pending_comment_count]).to eq(0)
    end
  end
end
