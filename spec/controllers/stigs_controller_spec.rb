# frozen_string_literal: true

# spec/controllers/stigs_controller_spec.rb
require 'rails_helper'

RSpec.describe StigsController, type: :controller do
  include LoginHelpers

  let(:stig) { create(:stig) }
  let(:user) { create(:user) }
  let(:user2) { create(:user) }

  before do
    user.admin = true
    user.save!
    # allow(controller).to receive(:current_user).and_return(user)
    # sign_in user
  end

  describe 'POST #create' do
    it 'allows admin to create a new Stig' do
      sign_in user
      expect do
        post :create, params: { file: stig.xml }
      end.to change(Stig, :count).by(1)
      expect(response.status).to be(302)
    end
  end

  describe 'DELETE #destroy' do
    it 'allows admin to destroy the stig' do
      sign_in user
      stig2 = Stig.from_mapping(Xccdf::Benchmark.parse(stig.xml))
      stig2.xml = stig.xml
      stig2.name = stig.name
      stig2.save!

      expect do
        delete :destroy, params: { id: stig2.id }
      end.to change(Stig, :count).by(-1)
    end

    it 'does not allow non admin to destroy the stig' do
      sign_in user2
      stig2 = Stig.from_mapping(Xccdf::Benchmark.parse(stig.xml))
      stig2.xml = stig.xml
      stig2.name = stig.name
      stig2.save!

      expect do
        delete :destroy, params: { id: stig2.id }
      end.not_to change(Stig, :count)
    end
  end
end
