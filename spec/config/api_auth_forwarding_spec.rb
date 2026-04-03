# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API authentication argument forwarding' do
  # REQUIREMENT: Api::BaseController#authenticate_user! must accept and forward
  # arguments to Devise's super. Uses Ruby 3 anonymous forwarding (*).

  let(:controller) { Rails.root.join('app/controllers/api/base_controller.rb').read }

  it 'accepts arguments in authenticate_user! signature' do
    expect(controller).to match(/def authenticate_user!\(\*\)/),
                          'authenticate_user! must accept * args for Devise compatibility'
  end
end
