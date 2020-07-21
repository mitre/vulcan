# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PagesController do
  let(:user1) { create(:user) }
  let(:message1) { build(:message) }

  before(:each) do
    @request.env['devise.mapping'] = Devise.mappings[:user]
    sign_in user1
  end

  context 'page controll' do
    it 'message pass' do
      get :home
      expect(response).to render_template('home')
    end
  end
end
