Rails.application.routes.draw do
  devise_for :users, controllers: { 
    registrations: 'users/registrations',
    sessions: 'users/sessions' ,
    omniauth_callbacks: 'callbacks'
  }
  
  devise_scope :user do
    get 'show_user', to: 'users/sessions#show'
  end

  resources :project_controls
  resources :projects
  resources :srg_controls
  resources :srgs
  resources :srg
  resources :pages
  
  match 'upload_srg' => 'srgs#upload', :as => :upload_srg, :via => :post
  match 'upload_project' => 'projects#upload', :as => :upload_project, :via => :post
  match 'render_modal' => 'project_controls#render_modal', :as => :render_modal, :via => :get
  match 'project/:id/edit_controls' => 'projects#edit_project_controls', :as => :project_edit_controls, :via => :get
  match 'project_controls/:id/review_control' => 'project_controls#review_control', :as => :review_control, :via => :get
  match 'add_history' => 'project_control_histories#add_history', :as => :add_history, :via => :post
  match 'add_host_config' => 'host_configs#add_host_config', :as => :add_host_config, :via => :post
  match 'delete_host_config' => 'host_configs#delete_host_config', :as => :delete_host_config, :via => :post
  match 'project_controls/:id/test_controls' => 'projects#test', :as => :test, :via => :get
  match 'project_controls/:id/run_test' => 'project_controls#run_test', :as => :run_test, :via => :get
  root 'dashboard#index', as: :home
end
