require 'rails_helper'

RSpec.describe User, type: :model do
  let(:user) { FactoryBot.build(:user) }
  # context 'with User' do
  #   let(:vendor) { FactoryBot.create(:vendor) }
  #   let(:project) { FactoryBot.build(:project) }
  # end
  
  it "has a valid factory" do
    expect(user).to be_valid
  end
  
  describe User do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_presence_of(:encrypted_password) }
  end
end
