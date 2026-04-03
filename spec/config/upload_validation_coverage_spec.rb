# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'upload validation coverage' do
  # All endpoints accepting file uploads must run validate_component_upload
  # to enforce size and type restrictions. Missing this filter lets users
  # upload arbitrarily large or wrong-type files.

  include ConfigFileHelpers

  it 'detect_srg is guarded by validate_component_upload' do
    before_action_line = grep_config(
      'app/controllers/components_controller.rb',
      /before_action\s+:validate_component_upload/
    ).first

    expect(before_action_line).not_to be_nil,
                                      'validate_component_upload before_action not found'
    expect(before_action_line).to match(/detect_srg/),
                                  'detect_srg must be in validate_component_upload only: list'
  end
end
