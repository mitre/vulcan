# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  include LoginHelpers

  describe '.from_omniauth' do
    context 'when registering using an omniauth provider' do
      let(:user1) { build(:user) }

      it 'creates the user and sets the user attributes' do
        auth = mock_omniauth_response(user1)
        expect { described_class.from_omniauth(auth) }.to change(described_class, :count).by 1

        created_user = described_class.find_by(email: user1.email)

        expect(created_user.email).to eq auth.info.email
        expect(created_user.name).to eq auth.info.name
        expect(created_user.provider).to eq auth.provider
        expect(created_user.provider).to eq auth.provider
      end
    end

    context 'when accessing an existing account using an omniauth provider' do
      let(:user1) { create(:user) }

      it 'does not create a duplicate user' do
        auth = mock_omniauth_response(user1)
        expect { described_class.from_omniauth(auth) }.not_to change(described_class, :count)
      end
    end
  end
end
