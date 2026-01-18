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
    # Authentication endpoints
    namespace :auth do
      post 'login', to: 'sessions#create'
      delete 'logout', to: 'sessions#destroy'
      get 'me', to: 'sessions#show'
    end

    get 'navigation', to: 'navigation#show'
    get 'search/global', to: 'search#global'

    # Public settings (no auth required)
    get 'settings', to: 'settings#index'
    get 'settings/consent_banner', to: 'settings#consent_banner' # Legacy endpoint

    # Project member management
    resources :projects, only: [] do
      member do
        get 'search_users', to: 'projects#search_users'
      end
    end

    # Find and Replace API (component-scoped)
    scope 'components/:component_id/find_replace' do
      post 'find', to: 'find_replace#find'
      post 'replace_instance', to: 'find_replace#replace_instance'
      post 'replace_field', to: 'find_replace#replace_field'
      post 'replace_all', to: 'find_replace#replace_all'
      post 'undo', to: 'find_replace#undo'
    end
  end

  # Admin namespace for admin-only functionality
  namespace :admin do
    get '/', to: 'dashboard#index', as: :root
    get 'stats', to: 'dashboard#stats'

    resources :users, only: %i[index show update destroy] do
      member do
        post 'lock'
        post 'unlock'
        post 'reset_password'
        post 'resend_confirmation'
      end
      collection do
        post 'invite'
      end
    end

    get 'settings', to: 'settings#index'

    resources :audits, only: %i[index show] do
      collection do
        get 'stats'
      end
    end
  end

  # Prometheus metrics are served on port 9394 by prometheus_exporter
  # Access at: http://localhost:9394/metrics (in development)
  # In Kubernetes: prometheus_exporter runs in same container, port 9394
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations: 'users/registrations',
    sessions: 'sessions',
    confirmations: 'users/confirmations',
    unlocks: 'users/unlocks',
    passwords: 'users/passwords'
  }, skip: [:sessions]

  # Custom sessions routes - GET serves SPA (public), POST goes to API
  devise_scope :user do
    get '/users/sign_in', to: 'public#index' # SPA handles login UI (no auth required)
    post '/users/sign_in', to: 'sessions#create' # API endpoint
    get '/users/sign_out', to: 'sessions#destroy' # Allow GET for navbar links
    delete '/users/sign_out', to: 'sessions#destroy' # API endpoint
  end

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

  # Editor2 demo page (must come before :stig_id catch-all)
  get '/components/:component_id/editor2', to: 'projects#index'

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

  # Root serves SPA shell - Vue Router handles auth/routing client-side
  root to: 'public#index'

  # SPA routes - serve the SPA shell for client-side routing
  # These routes don't need their own controller actions, they just render the SPA
  # The Vue Router handles the actual routing client-side
  # Redirect old /profile route to new /account/settings
  get '/profile', to: redirect('/account/settings')

  # Account settings (Vue SPA handles routing)
  get '/account/settings', to: 'projects#index'

  # Auth helper pages (Vue SPA handles routing) - login handled separately above
  # Use PublicController (no auth required) instead of ProjectsController
  get '/auth/confirmation', to: 'public#index'
  get '/auth/unlock', to: 'public#index'
  get '/auth/forgot-password', to: 'public#index'
  get '/auth/reset-password', to: 'public#index'

  get '/benchmarks', to: 'projects#index'
  get '/rules/:id/edit', to: 'projects#index'

  # Admin SPA routes (Vue Router handles these, Rails just serves the shell)
  get '/admin/audit', to: 'admin/dashboard#index'
  get '/admin/content/benchmarks', to: 'admin/dashboard#index'
  get '/admin/content/stigs', to: 'admin/dashboard#index'
  get '/admin/content/srgs', to: 'admin/dashboard#index'

  # Experimental routes (development/test only)
  # Load experimental UI prototypes that are not production-ready
  if Rails.env.development? || Rails.env.test?
    draw(:experimental)
  end

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
