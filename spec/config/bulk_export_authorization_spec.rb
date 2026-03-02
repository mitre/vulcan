# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'bulk_export authorization' do
  # Released components are the public catalog of published STIGs.
  # Any logged-in user may view and export them — no project membership required.
  #
  # REQUIREMENT: bulk_export must:
  # 1. Require authentication (authorize_logged_in)
  # 2. Scope queries to released: true (never expose draft components)

  include ConfigFileHelpers

  let(:controller_source) { Rails.root.join('app/controllers/components_controller.rb').read }

  describe 'authentication' do
    it 'bulk_export is protected by authorize_logged_in' do
      # Extract the before_action line that includes bulk_export
      auth_line = controller_source.lines.find { |l| l.include?('bulk_export') && l.include?('before_action') }
      expect(auth_line).to be_present
      expect(auth_line).to include('authorize_logged_in'),
                           'bulk_export must require authentication via authorize_logged_in'
    end
  end

  describe 'data scoping' do
    it 'bulk_export only queries released components' do
      # Find the bulk_export method and check it scopes to released: true
      in_method = false
      found_released_scope = false

      controller_source.each_line do |line|
        in_method = true if line.include?('def bulk_export')
        next unless in_method

        if line.include?('released: true')
          found_released_scope = true
          break
        end

        # Stop at next method definition
        break if in_method && line.match?(/^\s+def\s/) && line.exclude?('def bulk_export')
      end

      expect(found_released_scope).to be(true),
                                      'bulk_export must scope queries to released: true to prevent exposing draft components'
    end
  end
end
