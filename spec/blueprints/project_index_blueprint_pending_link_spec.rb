# frozen_string_literal: true

require 'rails_helper'

# Verifies the projects-list payload includes pending_comment_link, the
# server-resolved deep-link target for the "Comments" column. This avoids
# bouncing through the project-detail page when the deep-link target is
# unambiguous (PR #717 follow-on, Aaron's "feels clunky" feedback).
RSpec.describe 'ProjectIndexBlueprint pending_comment_link' do
  let_it_be(:srg) { create(:security_requirements_guide) }
  let_it_be(:project_single) { create(:project) }
  let_it_be(:project_multi) { create(:project) }
  let_it_be(:project_zero) { create(:project) }
  let_it_be(:single_component) { create(:component, project: project_single, based_on: srg) }
  let_it_be(:multi_a) { create(:component, project: project_multi, based_on: srg) }
  let_it_be(:multi_b) { create(:component, project: project_multi, based_on: srg) }

  let(:counts) { { project_single.id => 1, project_multi.id => 2 } }
  let(:targets) { { project_single.id => single_component.id } }

  def render_project(project)
    ProjectIndexBlueprint.render_as_hash(
      project,
      pending_comment_counts: counts,
      pending_comment_target_components: targets
    )
  end

  it 'links directly to the only component when one component has pending' do
    expect(render_project(project_single)[:pending_comment_link])
      .to eq("/components/#{single_component.id}#comments")
  end

  it 'falls back to the project page when multiple components have pending' do
    expect(render_project(project_multi)[:pending_comment_link])
      .to eq("/projects/#{project_multi.id}#comments")
  end

  it 'returns nil when the project has zero pending comments' do
    expect(render_project(project_zero)[:pending_comment_link]).to be_nil
  end

  it 'returns nil when no options are passed (defensive default)' do
    json = ProjectIndexBlueprint.render_as_hash(project_single)
    expect(json[:pending_comment_link]).to be_nil
  end
end
