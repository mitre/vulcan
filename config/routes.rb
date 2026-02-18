# frozen_string_literal: true

Rails.application.routes.draw do
  # Rails 8 built-in health check endpoint (simple liveness probe)
  get '/up' => 'rails/health#show', as: :rails_health_check

  # Health check gem routes for comprehensive checks (readiness probes)
  # Provides /health_check, /health_check/database, /health_check/migrations etc.
  health_check_routes

  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations: 'users/registrations',
    sessions: 'sessions'
  }

  resources :users, only: %i[index create update destroy]
  resources :srgs, only: %i[index show create destroy], controller: 'security_requirements_guides'
  resources :stigs, only: %i[index show create destroy]

  resources :memberships, only: %i[create update destroy]
  resources :projects, except: %i[new edit] do
    resources :components, only: %i[show create update destroy], shallow: true do
      post 'lock', to: 'reviews#lock_controls'
      resources :rules, only: %i[index show create update destroy], shallow: true do
        post 'revert', on: :member
        resources :comments, only: %i[create]
        resources :reviews, only: %i[create]
      end
    end
    resources :project_access_requests, only: %i[create destroy]
  end
  resources :rule_satisfactions, only: %i[create destroy]
  # Edit controls for a component (rules#index with editor view)
  get '/components/:component_id/edit', to: 'rules#index'
  # Legacy alias - redirect to new path
  get '/components/:component_id/controls', to: redirect('/components/%{component_id}/edit')

  # Bulk export multiple components (e.g. from ProjectComponents page)
  # Must be before /:id/:stig_id catch-all to avoid route collision
  get '/components/bulk_export/:type', to: 'components#bulk_export'

  # Add deep linking to specific rule (stig_id of format XXXX-XX-000000)
  get '/components/:id/:stig_id', to: 'components#show'

  # Make components#index not a child of project
  get '/components', to: 'components#index'
  # Revision history between components
  post '/components/history', to: 'components#history'
  # Export component
  get '/components/:id/export/:type', to: 'components#export'
  # Export STIG
  get '/stigs/:id/export/:type', to: 'stigs#export'
  # Export SRG
  get '/srgs/:id/export/:type', to: 'security_requirements_guides#export'
  # Components based on same srg
  get '/components/:id/search/based_on_same_srg', to: 'components#based_on_same_srg'
  # Compare components
  get '/components/:id/compare/:diff_id', to: 'components#compare'
  # Find
  post '/components/:id/find', to: 'components#find'
  # Export project
  get '/projects/:id/export/:type', to: 'projects#export'
  # Create new project from backup archive (before resources :projects to avoid id catch)
  post '/projects/create_from_backup', to: 'projects#create_from_backup'
  # Import backup archive into project
  post '/projects/:id/import_backup', to: 'projects#import_backup'
  # SRG ID Search (legacy routes)
  get '/search/projects', to: 'projects#search'
  get '/search/components', to: 'components#search'
  get '/search/rules', to: 'rules#search'
  get '/rules/:id/search/related_rules', to: 'rules#related_rules'

  # API namespace for JSON endpoints
  namespace :api do
    get 'search/global', to: 'search#global'
  end

  root to: 'projects#index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
