# frozen_string_literal: true

Rails.application.routes.draw do
  # Rails 8 built-in health check endpoint
  get '/up' => 'rails/health#show', as: :rails_health_check

  # Health check gem routes (must be before catchall routes)
  # Provides /health_check, /health_check/database, /health_check/migrations etc.
  health_check_routes

  # Application status endpoint
  get '/status' => 'status#show'

  # API namespace for SPA
  namespace :api do
    get 'navigation', to: 'navigation#show'
    get 'search/global', to: 'search#global'

    # Find and Replace API (component-scoped)
    scope 'components/:component_id/find_replace' do
      post 'find', to: 'find_replace#find'
      post 'replace_instance', to: 'find_replace#replace_instance'
      post 'replace_field', to: 'find_replace#replace_field'
      post 'replace_all', to: 'find_replace#replace_all'
      post 'undo', to: 'find_replace#undo'
    end
  end

  # Prometheus metrics are served on port 9394 by prometheus_exporter
  # Access at: http://localhost:9394/metrics (in development)
  # In Kubernetes: prometheus_exporter runs in same container, port 9394
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations: 'users/registrations',
    sessions: 'sessions'
  }

  resources :users, only: %i[index create update destroy]
  resources :srgs, only: %i[index show create destroy], controller: 'security_requirements_guides'
  resources :stigs, only: %i[index show create destroy]

  resources :memberships, only: %i[create update destroy]
  resources :projects do
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
  # Alias rules#index to controls for convenience
  get '/components/:component_id/controls', to: 'rules#index'

  # Add deep linking to specific rule (stig_id of format XXXX-XX-000000)
  get '/components/:id/:stig_id', to: 'components#show'

  # Make components#index not a child of project
  get '/components', to: 'components#index'
  # Revision history between components
  post '/components/history', to: 'components#history'
  # Export component
  get '/components/:id/export/:type', to: 'components#export'
  # Components based on same srg
  get '/components/:id/search/based_on_same_srg', to: 'components#based_on_same_srg'
  # Compare components
  get '/components/:id/compare/:diff_id', to: 'components#compare'
  # Find
  post '/components/:id/find', to: 'components#find'
  # Export project
  get '/projects/:id/export/:type', to: 'projects#export'
  # SRG ID Search
  get '/search/projects', to: 'projects#search'
  get '/search/components', to: 'components#search'
  get '/search/rules', to: 'rules#search'
  get '/rules/:id/search/related_rules', to: 'rules#related_rules'

  root to: 'projects#index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
