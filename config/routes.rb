# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    registrations: 'users/registrations'
  }

  root to: 'hello#index'
  get 'hello/index'
  get 'hello/projects', as: 'projects'

  # Furture
  # get 'hello/new_projects', as: 'new_projects'
  # get 'hello/srg', as: 'srg'
  # get 'hello/upload_srg', as: 'upload_srg'
  
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
