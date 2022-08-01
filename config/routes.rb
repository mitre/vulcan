# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations: 'users/registrations'
  }

  resources :users, only: %i[index create update destroy]
  resources :srgs, only: %i[index create destroy], controller: 'security_requirements_guides'

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
  end
  resources :rule_satisfactions, only: %i[create destroy]
  # Alias rules#index to controls for convenience
  get '/components/:component_id/controls', to: 'rules#index'
  # Make components#index not a child of project
  get '/components', to: 'components#index'
  # Revision history between components
  post '/components/history', to: 'components#history'
  # Export component
  get '/components/:id/export/:type', to: 'components#export'
  # Components based on same srg
  get '/components/:id/based_on_same_srg', to: 'components#based_on_same_srg'
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

  root to: 'projects#index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
