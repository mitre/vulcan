# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Lockout Settings' do
  describe 'Settings.lockout' do
    it 'exposes enabled as boolean' do
      expect(Settings.lockout.enabled).to be_in([true, false])
    end

    it 'defaults enabled to true' do
      expect(Settings.lockout.enabled).to be true
    end

    it 'exposes maximum_attempts as integer' do
      expect(Settings.lockout.maximum_attempts).to be_a(Integer)
    end

    it 'defaults maximum_attempts to 3' do
      expect(Settings.lockout.maximum_attempts).to eq(3)
    end

    it 'exposes unlock_in_minutes as integer' do
      expect(Settings.lockout.unlock_in_minutes).to be_a(Integer)
    end

    it 'defaults unlock_in_minutes to 15' do
      expect(Settings.lockout.unlock_in_minutes).to eq(15)
    end

    it 'exposes unlock_strategy as string' do
      expect(Settings.lockout.unlock_strategy).to be_a(String)
    end

    it 'defaults unlock_strategy to both' do
      expect(Settings.lockout.unlock_strategy).to eq('both')
    end

    it 'exposes last_attempt_warning as boolean' do
      expect(Settings.lockout.last_attempt_warning).to be true
    end
  end
end
