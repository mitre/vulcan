# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Messages', type: :request do
  describe 'When redirecting to Project page' do
    it 'get /pages/home' do
      get '/pages/home'
      expect(response).to have_http_status(:redirect)
    end
  end
end
