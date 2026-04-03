# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sections param type safety' do
  # REQUIREMENT: params[:sections] must be coerced to Array in all controllers
  # that use it. A string value causes validation bypass (String#- does character
  # deletion, not array subtraction) and downstream NoMethodError crashes.

  include ConfigFileHelpers

  let(:rules_controller) { Rails.root.join('app/controllers/rules_controller.rb').read }
  let(:reviews_controller) { Rails.root.join('app/controllers/reviews_controller.rb').read }

  describe 'rules_controller bulk_section_locks' do
    it 'coerces params[:sections] to Array' do
      expect(rules_controller).to match(/Array\(params\[:sections\]\)/),
                                  'bulk_section_locks must use Array(params[:sections]) to prevent string subtraction bypass'
    end
  end

  describe 'reviews_controller lock_sections' do
    it 'coerces params[:sections] to Array' do
      expect(reviews_controller).to match(/Array\(params\[:sections\]\)/),
                                    'lock_sections must use Array(params[:sections]) to prevent string subtraction bypass'
    end
  end
end
