# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Messages', type: :request do
  describe 'GET /pages/home' do
    it 'returns http redirect' do
      get '/pages/home'
      expect(response).to have_http_status(:redirect)
    end
  end
end
