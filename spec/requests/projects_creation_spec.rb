# frozen_string_literal: true

require 'rails_helper'

# ==========================================================================
# REQUIREMENT: POST /projects accepts the full creation surface in one call.
# Project metadata uses ONE shape — the same project_metadata_attributes
# nested form the update path accepts — and the slack_channel_id convenience
# param keeps working, merging into the same metadata record rather than
# introducing a second convention. A metadata payload sent at creation must
# persist; silently dropping accepted params is a contract violation.
# ==========================================================================
RSpec.describe 'Project creation' do
  let_it_be(:admin_user) { create(:user, admin: true) }

  before do
    Rails.application.reload_routes!
    sign_in admin_user
  end

  describe 'POST /projects with project_metadata_attributes' do
    it 'persists metadata provided in the same call' do
      post '/projects',
           params: {
             project: {
               name: 'Metadata At Creation',
               description: 'One-call create',
               visibility: 'discoverable',
               project_metadata_attributes: {
                 data: { 'POC Name' => 'Jane Doe', 'POC Email' => 'jane@example.com' }
               }
             }
           },
           headers: { 'Accept' => 'application/json' }, as: :json

      expect(response).to have_http_status(:ok)
      project = Project.find_by!(name: 'Metadata At Creation')
      expect(project.project_metadata.data)
        .to eq('POC Name' => 'Jane Doe', 'POC Email' => 'jane@example.com')
    end

    it 'keeps the slack_channel_id convenience path working (regression)' do
      post '/projects',
           params: {
             project: {
               name: 'Slack Convenience',
               description: '',
               visibility: 'discoverable',
               slack_channel_id: 'C0123456789'
             }
           },
           headers: { 'Accept' => 'application/json' }, as: :json

      expect(response).to have_http_status(:ok)
      project = Project.find_by!(name: 'Slack Convenience')
      expect(project.project_metadata.data).to eq('Slack Channel ID' => 'C0123456789')
    end

    it 'merges the slack convenience param into provided metadata — one record, param wins on conflict' do
      post '/projects',
           params: {
             project: {
               name: 'Merged Metadata',
               description: '',
               visibility: 'discoverable',
               slack_channel_id: 'C0999999999',
               project_metadata_attributes: {
                 data: { 'POC Name' => 'Jane Doe', 'Slack Channel ID' => 'C0000000000' }
               }
             }
           },
           headers: { 'Accept' => 'application/json' }, as: :json

      expect(response).to have_http_status(:ok)
      project = Project.find_by!(name: 'Merged Metadata')
      expect(project.project_metadata.data)
        .to eq('POC Name' => 'Jane Doe', 'Slack Channel ID' => 'C0999999999')
    end

    it 'creates no metadata record when neither metadata nor slack id is sent' do
      post '/projects',
           params: {
             project: { name: 'No Metadata', description: '', visibility: 'discoverable' }
           },
           headers: { 'Accept' => 'application/json' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(Project.find_by!(name: 'No Metadata').project_metadata).to be_nil
    end
  end
end
