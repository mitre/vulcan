# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper do
  before do
    Rails.application.reload_routes!
  end

  describe '#base_navigation' do
    subject(:navigation) { helper.base_navigation }

    it 'links the four primary sections' do
      expect(navigation.pluck(:link)).to include('/projects', '/components', '/stigs', '/srgs')
    end

    it 'offers a single documentation entry pointing at the docs route' do
      documentation = navigation.find { |item| item[:name] == 'Documentation' }
      expect(documentation).not_to be_nil, 'no Documentation entry in the navigation'
      expect(documentation[:link]).to eq('/docs')
      expect(documentation).not_to have_key(:children)
    end

    # The docs entry replaced a dropdown whose only child was the DISA guide —
    # a single-child dropdown is the shape this card removes, not just moves.
    it 'leaves no single-child dropdown behind' do
      navigation.select { |item| item.key?(:children) }.each do |item|
        expect(item[:children].size).to be > 1,
                                        "#{item[:name]} is a dropdown with #{item[:children].size} child"
      end
    end
  end
end
