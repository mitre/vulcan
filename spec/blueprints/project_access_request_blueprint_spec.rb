# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProjectAccessRequestBlueprint do
  let_it_be(:user) { create(:user, name: 'Request User', email: 'requester@test.com') }
  let_it_be(:project) { create(:project, name: 'Test Project') }
  let_it_be(:access_request) do
    ProjectAccessRequest.find_or_create_by!(user: user, project: project)
  end

  subject(:result) { described_class.render_as_json(access_request) }

  it 'includes id as an integer' do
    expect(result['id']).to eq(access_request.id)
  end

  it 'nests user with id, name, email via UserBlueprint' do
    expect(result['user']).to be_a(Hash)
    expect(result['user']['id']).to eq(user.id)
    expect(result['user']['name']).to eq('Request User')
    expect(result['user']['email']).to eq('requester@test.com')
  end

  it 'nests project with id and name' do
    expect(result['project']).to be_a(Hash)
    expect(result['project']['id']).to eq(project.id)
    expect(result['project']['name']).to eq('Test Project')
  end

  it 'has consistent string keys at all nesting levels' do
    expect(result.keys).to all(be_a(String))
    expect(result['user'].keys).to all(be_a(String))
    expect(result['project'].keys).to all(be_a(String))
  end

  it 'does NOT include project_id at the top level (nested project has it)' do
    expect(result).not_to have_key('project_id')
  end

  it 'does NOT include user_id at the top level (nested user has it)' do
    expect(result).not_to have_key('user_id')
  end

  describe 'collection rendering' do
    it 'renders an array of access requests' do
      results = described_class.render_as_json([access_request])

      expect(results).to be_an(Array)
      expect(results.length).to eq(1)
      expect(results.first['id']).to eq(access_request.id)
    end
  end
end
