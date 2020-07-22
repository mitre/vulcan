# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  context 'Creates a message' do
    let(:msg) { build(:message) }
    it 'checks the message body' do
      expect(msg.body).to eq('test')
    end
  end
end
