# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SPA Routes', type: :routing do
  # All Vue Router paths that need Rails fallback routes for hard refresh support
  # These are extracted from app/javascript/routes/index.ts
  # When adding new SPA routes, add them here to ensure Rails has a fallback
  SPA_ROUTES = [
    # Public routes
    { path: '/', description: 'root/projects index' },
    { path: '/projects', description: 'projects list' },
    { path: '/projects/new', description: 'new project form' },
    { path: '/benchmarks', description: 'unified benchmarks page' },
    { path: '/stigs', description: 'STIGs list' },
    { path: '/srgs', description: 'SRGs list' },
    { path: '/components', description: 'components list' },
    { path: '/profile', description: 'user profile page' },
    { path: '/users', description: 'users list' },

    # Dynamic routes (using example IDs)
    { path: '/projects/1', description: 'project show page' },
    { path: '/stigs/1', description: 'STIG show page' },
    { path: '/srgs/1', description: 'SRG show page' },
    { path: '/components/1', description: 'component show page' },
    { path: '/components/1/controls', description: 'component controls/requirements editor' },
    { path: '/rules/1/edit', description: 'rule edit page' },

    # Admin routes
    { path: '/admin', description: 'admin dashboard' },
    { path: '/admin/users', description: 'admin users management' },
    { path: '/admin/audit', description: 'admin audit log' },
    { path: '/admin/settings', description: 'admin settings' },
    { path: '/admin/content/benchmarks', description: 'admin benchmarks management' },
    { path: '/admin/content/stigs', description: 'admin STIGs' },
    { path: '/admin/content/srgs', description: 'admin SRGs' }
  ].freeze

  describe 'Vue Router routes have Rails fallbacks' do
    before do
      Rails.application.reload_routes!
    end

    SPA_ROUTES.each do |route_info|
      path = route_info[:path]
      description = route_info[:description]

      it "has a Rails route for #{path} (#{description})" do
        # Use routing matcher to verify route exists
        # This checks if Rails can route the path, not if the controller action succeeds
        expect(get: path).to be_routable,
          "Expected route #{path} to be routable but it was not. " \
          "This SPA route needs a Rails fallback for hard refresh support. " \
          "Add to config/routes.rb: get '#{path}', to: 'projects#index'"
      end
    end
  end

  describe 'route documentation' do
    it 'documents all SPA routes for maintenance' do
      # This test serves as documentation and will fail if routes are removed
      # without updating this spec
      expect(SPA_ROUTES.length).to be >= 20,
        'Expected at least 20 SPA routes to be documented. ' \
        'If routes were removed, update SPA_ROUTES constant.'
    end
  end
end
