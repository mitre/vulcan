# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations: 'users/registrations'
  }

  resources :users, only: %i[index create update destroy]

  resources :projects do
    resources :project_members, only: %i[index create update destroy]
    resources :rules, shallow: true do
      post 'manage_lock', on: :member
      post 'revert', on: :member
      resources :comments, only: %i[create]
    end
  end
  # Alias rules#index to controls for convenience
  get '/projects/:project_id/controls', to: 'rules#index'

  root to: 'hello#index'
  get 'hello/index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
