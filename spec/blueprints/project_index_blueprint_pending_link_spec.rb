# frozen_string_literal: true

require 'rails_helper'

# Verifies the projects-list payload includes pending_comment_link, the
# server-resolved deep-link target for the "Comments" column. This avoids
# bouncing through the project-detail page when the deep-link target is
# unambiguous.
RSpec.describe 'ProjectIndexBlueprint pending_comment_link' do
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:project_single) { create(:project) }
  let_it_be(:project_multi) { create(:project) }
  let_it_be(:project_closed_only) { create(:project) }
  let_it_be(:project_zero) { create(:project) }
  let_it_be(:single_component) { create(:component, project: project_single, based_on: srg) }
  let_it_be(:multi_a) { create(:component, project: project_multi, based_on: srg) }
  let_it_be(:multi_b) { create(:component, project: project_multi, based_on: srg) }
  let_it_be(:closed_only_component) { create(:component, project: project_closed_only, based_on: srg) }

  let(:counts) do
    {
      project_single.id => { pending: 1, total: 1 },
      project_multi.id => { pending: 2, total: 5 },
      project_closed_only.id => { pending: 0, total: 4 }
    }
  end
  let(:targets) { { project_single.id => single_component.id } }

  def render_project(project)
    ProjectIndexBlueprint.render_as_hash(
      project,
      comment_counts: counts,
      pending_comment_target_components: targets
    )
  end

  it 'links directly to the only component when one component has pending' do
    expect(render_project(project_single)[:pending_comment_link])
      .to eq("/components/#{single_component.id}/triage")
  end

  it 'falls back to the project page when multiple components have pending' do
    expect(render_project(project_multi)[:pending_comment_link])
      .to eq("/projects/#{project_multi.id}/triage")
  end

  it 'links to the project page when total > 0 but pending = 0 (closed-only view)' do
    expect(render_project(project_closed_only)[:pending_comment_link])
      .to eq("/projects/#{project_closed_only.id}/triage")
  end

  it 'returns nil when the project has zero comments at all' do
    expect(render_project(project_zero)[:pending_comment_link]).to be_nil
  end

  it 'returns nil when no options are passed (defensive default)' do
    json = ProjectIndexBlueprint.render_as_hash(project_single)
    expect(json[:pending_comment_link]).to be_nil
  end

  it 'exposes pending_comment_count and total_comment_count alongside the link' do
    json = render_project(project_multi)
    expect(json[:pending_comment_count]).to eq(2)
    expect(json[:total_comment_count]).to eq(5)
  end

  it 'falls back to 0/0 when a project is missing from the counts hash' do
    json = render_project(project_zero)
    expect(json[:pending_comment_count]).to eq(0)
    expect(json[:total_comment_count]).to eq(0)
  end
end
