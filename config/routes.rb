# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations: 'users/registrations'
  }

  resources :users, only: %i[index create update destroy]

  resources :projects do
    resources :users, as: :project_members, only: %i[index create update destroy]
    resources :controls, shallow: true, as: :rules do
      resources :comments, only: %i[index], shallow: true
    end
  end

  resources :comments, except: %i[index new]

  root to: 'hello#index'
  get 'hello/index'
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
