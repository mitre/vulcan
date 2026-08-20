# frozen_string_literal: true

require 'rails_helper'

# REQUIREMENTS:
#
# 1. GET /projects/:id renders the project + its components without
#    raising on attributes the components were not loaded with.
#    Project#available_components uses .select(...) which limits the
#    columns loaded; the ProjectBlueprint :show view fans out to
#    ComponentBlueprint :index for both project.components and
#    project.available_components, so any field promoted to
#    ComponentBlueprint's *default* fieldset MUST be present in that
#    select(...) list — otherwise we hit ActiveModel::MissingAttributeError
#    on render. (PR #717 regression: comment_phase + comment_period_ends_at
#    were briefly added to default fields and broke this path because
#    available_components doesn't load them.)
# 2. The endpoint must successfully serialize when the released-status,
#    rules_count, comment_phase, etc. are set on at least one component
#    in scope.
RSpec.describe 'GET /projects/:id' do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:component) { create(:component, project: project) }

  before do
    Rails.application.reload_routes!
    sign_in user
    Membership.create!(user: user, membership: project, role: 'admin')
  end

  it 'renders without ActiveModel::MissingAttributeError when an available_component exists' do
    # Trigger the available_components path: a released component in another
    # project is "available" for import. Project#available_components uses
    # .select(:id, :name, :prefix, :version, :release, :project_id,
    #        :security_requirements_guide_id, :released, :updated_at,
    #        :rules_count, :component_id) — anything required by
    # ComponentBlueprint :index that is NOT in that list will blow up here.
    other_project = create(:project)
    create(:component, project: other_project, released: true)

    expect { get "/projects/#{project.id}", as: :json }.not_to raise_error
    expect(response).to have_http_status(:success)
  end

  it 'renders successfully when components have comment_phase + period dates set' do
    component.update!(comment_phase: 'open',
                      comment_period_ends_at: 30.days.from_now)

    get "/projects/#{project.id}", as: :json
    expect(response).to have_http_status(:success)
  end

  describe 'component card counts (ComponentBlueprint :index)' do
    it 'serves the authored requirement count for an srg-kind component under rules_count' do
      srg_component = create(:component, :skip_rules, project: project, document_type: 'srg',
                                                      prefix: 'PSRG-00', name: 'Project SRG',
                                                      title: 'Project SRG')
      create(:srg_rule, :authored, component: srg_component, rule_id: '000001')

      get "/projects/#{project.id}", as: :json

      row = response.parsed_body['components'].find { |c| c['id'] == srg_component.id }
      expect(row['rules_count']).to eq(1)
    end

    it 'serves the kind-aware count through the column-limited available_components path' do
      other_project = create(:project)
      released_srg = create(:component, :skip_rules, project: other_project, document_type: 'srg',
                                                     prefix: 'ASRG-00', name: 'Available SRG',
                                                     title: 'Available SRG')
      create(:srg_rule, :authored, component: released_srg, rule_id: '000001',
                                   status: 'Applicable', locked: true)
      released_srg.update!(released: true, via_release_flow: true)

      get "/projects/#{project.id}", as: :json

      expect(response).to have_http_status(:success)
      row = response.parsed_body['available_components'].find { |c| c['id'] == released_srg.id }
      expect(row['rules_count']).to eq(1)
    end
  end

  describe 'effective_permissions in JSON response' do
    it 'includes effective_permissions=admin for project admin' do
      get "/projects/#{project.id}", as: :json
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['effective_permissions']).to eq('admin')
    end

    it 'includes effective_permissions=viewer for viewer member' do
      viewer = create(:user)
      Membership.create!(user: viewer, membership: project, role: 'viewer')
      sign_in viewer
      get "/projects/#{project.id}", as: :json
      expect(response).to have_http_status(:success)
      expect(response.parsed_body['effective_permissions']).to eq('viewer')
    end
  end
end
