# frozen_string_literal: true

# spec/models/project_access_request_spec.rb
require 'rails_helper'

RSpec.describe ProjectAccessRequest do
  let(:user1) { create(:user) }
  let(:user2) { create(:user) }
  let(:project) { create(:project) }

  context 'associations' do
    it 'belongs to user' do
      access_request = ProjectAccessRequest.new(user: user1, project: project)
      expect(access_request.user).to eq(user1)
    end

    it 'belongs to project' do
      access_request = ProjectAccessRequest.new(user: user1, project: project)
      expect(access_request.project).to eq(project)
    end
  end

  context 'validations' do
    it 'validates uniqueness of user scoped to project' do
      create(:project_access_request, user: user1, project: project)
      duplicate_request = ProjectAccessRequest.new(user: user1, project: project)
      duplicate_request.valid?
      expect(duplicate_request.errors[:user_id]).to include('has already requested access to this project')
    end
  end
end
