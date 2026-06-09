# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Component destruction' do
  include_context 'components request base setup'

  describe 'DELETE /components/:id' do
    it 'destroys component and all dependent records' do
      doomed = create(:component, project: project)
      rule_ids = doomed.rules.pluck(:id)

      delete "/components/#{doomed.id}",
             headers: { 'Accept' => application_json }

      expect(response).to have_http_status(:success)
      expect(Component.find_by(id: doomed.id)).to be_nil
      expect(Rule.unscoped.where(id: rule_ids).count).to eq(0)
    end

    context 'as project author (not admin)' do
      let(:author_user) { create(:user) }

      before do
        Membership.create!(user: author_user, membership: project, role: 'author')
        sign_in author_user
      end

      it 'rejects — destroy requires admin' do
        delete "/components/#{component.id}", headers: { 'Accept' => application_json }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      before { sign_out user }

      it 'redirects to sign-in' do
        delete "/components/#{component.id}", headers: { 'Accept' => application_json }
        expect(response).to have_http_status(:unauthorized)
          .or redirect_to(new_user_session_path)
      end
    end
  end
end
