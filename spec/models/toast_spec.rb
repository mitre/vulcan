# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Toast do
  describe '.new' do
    it 'wraps a string message into an array' do
      toast = described_class.new(title: 'Error', message: 'Something broke.', variant: 'danger')
      expect(toast.message).to eq(['Something broke.'])
    end

    it 'preserves an array message' do
      toast = described_class.new(title: 'Error', message: ['Line 1', 'Line 2'])
      expect(toast.message).to eq(['Line 1', 'Line 2'])
    end

    it 'handles ActiveModel errors (responds to to_a)' do
      toast = described_class.new(title: 'Validation', message: ["Name can't be blank", 'Email is invalid'])
      expect(toast.message).to eq(["Name can't be blank", 'Email is invalid'])
    end

    it 'defaults variant to danger' do
      toast = described_class.new(title: 'Error', message: 'Fail')
      expect(toast.variant).to eq('danger')
    end

    it 'accepts custom variant' do
      toast = described_class.new(title: 'Done', message: 'Saved', variant: 'success')
      expect(toast.variant).to eq('success')
    end

    it 'handles nil message as empty array' do
      toast = described_class.new(title: 'Empty', message: nil)
      expect(toast.message).to eq([])
    end
  end

  describe '#as_json' do
    it 'returns the canonical toast hash' do
      toast = described_class.new(title: 'Created.', message: 'User saved.', variant: 'success')
      expect(toast.as_json).to eq({
                                    'title' => 'Created.',
                                    'message' => ['User saved.'],
                                    'variant' => 'success'
                                  })
    end
  end

  describe '#to_json' do
    it 'serializes to valid JSON' do
      toast = described_class.new(title: 'Test', message: 'OK', variant: 'info')
      parsed = JSON.parse(toast.to_json)
      expect(parsed['title']).to eq('Test')
      expect(parsed['message']).to eq(['OK'])
      expect(parsed['variant']).to eq('info')
    end
  end

  describe 'immutability' do
    it 'freezes the message array' do
      toast = described_class.new(title: 'Frozen', message: 'Test')
      expect(toast.message).to be_frozen
    end
  end
end
