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

  it 'renders successfully when components have comment_phase set' do
    component.update!(comment_phase: 'open')

    get "/projects/#{project.id}", as: :json
    expect(response).to have_http_status(:success)
  end
end
