# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'JSON parameter safety' do
  # REQUIREMENT: Any controller that parses user-supplied JSON via JSON.parse
  # must rescue JSON::ParserError to prevent unhandled 500 errors.

  include ConfigFileHelpers

  let(:projects_controller) { Rails.root.join('app/controllers/projects_controller.rb').read }

  it 'component_filter rescues JSON::ParserError' do
    expect(projects_controller).to match(/rescue JSON::ParserError/),
                                   'component_filter must rescue JSON::ParserError to prevent 500 on invalid input'
  end
end
