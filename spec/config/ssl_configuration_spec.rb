# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SSL Configuration', type: :request do
  describe 'production environment SSL settings' do
    # These tests validate the fix for GitHub issues #700 and #702
    # - #700: Infinite redirect loop between /users/sign_in and /
    # - #702: Puma HTTP parse error on clean Docker install
    #
    # Root cause: Rails 8 defaults hardcoded assume_ssl=true and force_ssl=true
    # which breaks Docker quickstart deployments without SSL termination.

    it 'assume_ssl should be false (do not blindly assume SSL)' do
      # assume_ssl=true causes issues when accessing app directly without proxy
      production_rb = Rails.root.join("config/environments/production.rb").read

      expect(production_rb).to include('config.assume_ssl = false'),
                               'assume_ssl should be false - do not blindly assume SSL termination'
    end

    it 'force_ssl should be ENV-configurable with secure default' do
      production_rb = Rails.root.join("config/environments/production.rb").read

      # Should use ENV.fetch pattern for configurability
      expect(production_rb).to include('RAILS_FORCE_SSL'),
                               'force_ssl should be configurable via RAILS_FORCE_SSL env var'

      # Should default to true (secure by default)
      expect(production_rb).to match(/ENV\.fetch.*RAILS_FORCE_SSL.*true/),
                               'force_ssl should default to true for security'
    end

    it 'force_ssl can be disabled by setting RAILS_FORCE_SSL=false' do
      production_rb = Rails.root.join("config/environments/production.rb").read

      # Should check for "false" string to disable
      expect(production_rb).to match(/downcase.*!=.*['"]false['"]/),
                               'force_ssl should be disableable by setting RAILS_FORCE_SSL=false'
    end
  end
end
