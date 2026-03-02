# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'project_visibility param validation' do
  # REQUIREMENT: project_visibility from params must be validated against the
  # Project.visibilities enum allowlist. Arbitrary values cause unhandled
  # ArgumentError (500) because Rails enums raise on invalid assignment.

  include ConfigFileHelpers

  let(:controller) { Rails.root.join('app/controllers/projects_controller.rb').read }

  it 'validates project_visibility against allowed values before use' do
    # Must not pass raw params directly to Project.create — needs allowlist check
    expect(controller).to match(/Project\.visibilities\.keys|VALID_VISIBILITIES|visibilities\.include/),
                          'project_visibility must be validated against Project.visibilities.keys before assignment'
  end
end
