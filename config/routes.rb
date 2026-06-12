# frozen_string_literal: true

Rails.application.routes.draw do
  # Rails 8 built-in health check endpoint (simple liveness probe)
  get '/up' => 'rails/health#show', as: :rails_health_check

  # Health check gem routes for comprehensive checks (readiness probes)
  # Provides /health_check, /health_check/database, /health_check/migrations etc.
  health_check_routes

  # In-app DISA process guidance (works in airgapped environments)
  get '/disa-guide/attachments/:filename', to: 'disa_guide#attachment', as: :disa_guide_attachment, constraints: { filename: %r{[^/]+} }
  get '/disa-guide(/:page)', to: 'disa_guide#show', as: :disa_guide

  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations: 'users/registrations',
    sessions: 'sessions'
  }

  # Unlink an external identity (OIDC/LDAP/GitHub) from the current user account.
  # Requires current password. See Users::RegistrationsController#unlink_identity.
  devise_scope :user do
    # RP-initiated logout landing: the OIDC provider redirects here after
    # ending its session; the action sets the AC-12(02) signed-out flash and
    # forwards to the sign-in page. Must be registered with the provider as
    # an allowed post-logout redirect URI. See SessionsController#signed_out.
    get '/users/signed_out', to: 'sessions#signed_out', as: :signed_out
    post '/users/unlink_identity', to: 'users/registrations#unlink_identity', as: :unlink_identity
    post '/users/initiate_link', to: 'users/registrations#initiate_link', as: :initiate_link
    # Settings shell sub-pages — each section gets its own URL so it's
    # bookmarkable and can be linked to directly from notifications,
    # navbar dropdowns, etc. /users/edit (Devise's default) renders the
    # Profile Information section.
    get '/users/edit/password', to: 'users/registrations#edit_password', as: :edit_user_password_form
    get '/users/edit/activity', to: 'users/registrations#edit_activity', as: :edit_user_activity
    get '/users/edit/tokens', to: 'users/registrations#edit_tokens', as: :edit_user_tokens
  end

  resources :users, only: %i[index update destroy] do
    collection do
      post :admin_create
    end
    member do
      post :send_password_reset
      post :generate_reset_link
      post :set_password
      post :lock
      post :unlock
      # Privacy: only the user themselves can read their own comment list
      # (no admin override — see UsersController#authorize_self).
      # PR-717 .bpy — explicit action mapping per Sonar rubydre:S7875.
      get :comments, to: 'users#comments'
    end
  end
  resources :personal_access_tokens, only: %i[index create destroy] do
    member do
      delete :admin_revoke
    end
  end

  resources :srgs, only: %i[index show create destroy], controller: 'security_requirements_guides'
  resources :stigs, only: %i[index show create destroy]

  resources :memberships, only: %i[create update destroy]

  # /components/history must precede `resources :components` below or it
  # binds to components#show with :id="history" → 404. Same trap as /related.
  get '/components/history', to: 'components#history'

  resources :projects, except: %i[new edit] do
    resources :components, only: %i[show create update destroy], shallow: true do
      post 'lock', to: 'reviews#lock_controls'
      patch 'lock_sections', to: 'reviews#lock_sections'
      resources :reviews, only: %i[create]
      resources :rules, only: %i[index show create update destroy], shallow: true do
        post 'revert', on: :member
        patch 'section_locks', on: :member
        patch 'bulk_section_locks', on: :member
        resources :reviews, only: %i[create]
      end
    end
    resources :project_access_requests, only: %i[create destroy]
    resources :triage_response_templates, only: %i[index create update destroy]
  end
  resources :rule_satisfactions, only: %i[create destroy]
  # Edit controls for a component (rules#index with editor view)
  get '/components/:component_id/edit', to: 'rules#index'
  # Legacy alias - redirect to new path
  get '/components/:component_id/controls', to: redirect('/components/%{component_id}/edit')

  # Bulk export multiple components (e.g. from ProjectComponents page)
  # Must be before /:id/:stig_id catch-all to avoid route collision
  get '/components/bulk_export/:type', to: 'components#bulk_export'

  # Component activity history (B5 reactivity fix) — MUST be before :stig_id catch-all
  get '/components/:id/histories', to: 'components#histories'
  # Public-comment-review triage table (PR #717) — MUST be before :stig_id catch-all
  get '/components/:id/comments', to: 'components#comments'
  get '/components/:id/rules_picker', to: 'components#rules_picker'
  get '/components/:id/triage',   to: 'components#triage', as: :component_triage
  # Component admin settings page (PR #717 Task 22) — MUST be before :stig_id catch-all
  get '/components/:id/settings', to: 'components#settings', as: :component_settings
  # Component sync/merge status polling (Phase 2c) — POSTing a merge is
  # handled by /projects/:id/import_backup?merge=true&component_id=X.
  # MUST be before :stig_id catch-all.
  get '/components/:id/merge_status', to: 'components#merge_status', as: :component_merge_status
  get '/projects/:id/comments',   to: 'projects#comments'
  get '/projects/:id/triage',     to: 'projects#triage', as: :project_triage
  # Public-comment-review lifecycle endpoints (PR #717): triage / adjudicate /
  # reopen / withdraw / update operate on a Review by id. See ReviewsController.
  # Task 33: reply-chain reader. Auth via parent component's released-vs-member gate.
  # Bulk triage — declared before /reviews/:id/* so the literal segment wins.
  patch '/reviews/bulk_triage',         to: 'reviews#bulk_triage'
  patch '/reviews/merge',               to: 'reviews#merge'
  get   '/reviews/:id/responses',       to: 'reviews#responses'
  patch '/reviews/:id/triage',          to: 'reviews#triage'
  patch '/reviews/:id/adjudicate',      to: 'reviews#adjudicate'
  patch '/reviews/:id/reopen',          to: 'reviews#reopen'
  patch '/reviews/:id/withdraw',        to: 'reviews#withdraw'
  # PR-717 Task 25 — admin overrides on a comment. Audit-comment required.
  patch '/reviews/:id/admin_withdraw',  to: 'reviews#admin_withdraw'
  patch '/reviews/:id/admin_restore',   to: 'reviews#admin_restore'
  patch '/reviews/:id/move_to_rule',    to: 'reviews#move_to_rule'
  delete '/reviews/:id/admin_destroy',  to: 'reviews#admin_destroy'
  # PR-717 Task 30 — author+ retags a comment's section retroactively.
  patch '/reviews/:id/section',         to: 'reviews#section'
  put '/reviews/:id', to: 'reviews#update'
  # Reactions: POST toggles current_user's 👍/👎 on the review;
  # GET lists reactor names. POST is phase-gated (open only); GET is not.
  resources :reviews, only: [] do
    resources :reactions, only: %i[index create]
  end
  # Add deep linking to specific rule (stig_id of format XXXX-XX-000000)
  # keep specific named routes ABOVE the :stig_id catch-all,
  # otherwise /components/:id/<anything> binds to components#show with
  # :stig_id="<anything>" and rule-context filters 404 on a missing rule_id.
  get '/components/:id/related', to: 'components#based_on_same_srg'
  get '/components/:id/:stig_id', to: 'components#show'

  # Make components#index not a child of project
  get '/components', to: 'components#index'
  # /components/history is defined ABOVE `resources :components` (see comment there)
  # Export component
  get '/components/:id/export/:type', to: 'components#export'
  # Export STIG
  get '/stigs/:id/export/:type', to: 'stigs#export'
  # Export SRG
  get '/srgs/:id/export/:type', to: 'security_requirements_guides#export'
  # /related is defined ABOVE /components/:id/:stig_id (see comment there)
  # peer-shaped diff endpoint moved to /api/components/compare
  # (see Api namespace below). The old sub-resource path is removed.
  # Detect SRG from spreadsheet (auto-populate dropdown on import)
  post '/components/detect_srg', to: 'components#detect_srg'
  # Spreadsheet round-trip update
  post '/components/:id/preview_spreadsheet_update', to: 'components#preview_spreadsheet_update'
  patch '/components/:id/apply_spreadsheet_update', to: 'components#apply_spreadsheet_update'
  # Find
  post '/components/:id/find', to: 'components#find'
  # Project activity history (Phase 4)
  get '/projects/:id/histories', to: 'projects#histories'
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

  get 'api/docs', to: 'api_docs#show'
  get 'api/docs/openapi.yaml', to: 'api_docs#spec', as: :api_docs_spec
  get 'api/docs/openapi.yml', to: 'api_docs#spec'
  get 'api/docs/openapi.json', to: 'api_docs#spec_json'

  # API namespace for JSON endpoints
  namespace :api do
    get 'auth/me', to: 'auth#me'
    post 'auth/login', to: 'auth#login'
    delete 'auth/logout', to: 'auth#logout'
    get 'settings', to: 'settings#show'
    get 'navigation', to: 'navigation#show'

    get 'search/global', to: 'search#global'
    get 'users/search', to: 'user_search#index'
    get 'version', to: 'version#show'

    resources :projects, only: [:index]
    # peer-shaped diff endpoint. Route points at the existing
    # ComponentsController#compare action (not a new Api::ComponentsController)
    # to keep blast radius small for one endpoint.
    get 'components/compare', to: '/components#compare'
  end

  # AC-8: Server-side consent acknowledgment
  post '/consent/acknowledge', to: 'consent#acknowledge'

  root to: 'projects#index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
