# frozen_string_literal: true

# Experimental routes - loaded only in development/test environments
# See config/routes.rb for conditional loading
#
# These routes are for UI experiments and prototypes that should NOT
# be available in production until they're production-ready.

# Login2 - Classified terminal aesthetic experiment (frontend-design skill)
get '/login2', to: 'public#show' # No auth required for demo

# RequirementEditor2 - Bootstrap 5 + reference slideover experiment
get '/components/:id/editor2', to: 'projects#index' # SPA shell for Vue Router
