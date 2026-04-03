# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DISA Guide' do
  let_it_be(:user) { create(:user) }

  before do
    Rails.application.reload_routes!
  end

  context 'when authenticated' do
    before { sign_in user }

    it 'renders the overview page by default' do
      get '/disa-guide'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('DISA Process Guide')
    end

    it 'renders the field-requirements page' do
      get '/disa-guide/field-requirements'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Field Requirements')
    end

    it 'renders the export-requirements page' do
      get '/disa-guide/export-requirements'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Export Requirements')
    end

    it 'renders the intent-form page' do
      get '/disa-guide/intent-form'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Intent Form')
    end

    it 'returns 404 for nonexistent page' do
      get '/disa-guide/nonexistent'
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when unauthenticated' do
    it 'redirects to login' do
      get '/disa-guide'
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
