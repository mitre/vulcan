Rails.application.routes.draw do
  devise_for :users, controllers: { 
    registrations: 'users/registrations',
    sessions: 'users/sessions' ,
    omniauth_callbacks: 'users/omniauth_callbacks'
  }
  
  devise_scope :user do
    get 'show_user', to: 'users/sessions#show'
    post 'set_role' => 'users/registrations#set_role', :as => :set_role, :via => :post

    # put 'users' => 'users/registrations#update', :as => 'edit_user_profile'
    # match 'update_code' => 'project_controls#update_code', :as => :update_code, :via => :post
  end
  
  # devise_for :user                                      
  #   put 'users' => 'users/registrations#update', :as => 'user_registration'            
  # end

  resources :project_controls
  resources :projects
  resources :srg_controls
  resources :srgs
  resources :srg
  resources :pages
  resources :requests
  resources :vendors
  resources :sponsor_agencies

  match 'upload_srg' => 'srgs#upload', :as => :upload_srg, :via => :post
  match 'upload_project' => 'projects#upload', :as => :upload_project, :via => :post
  match 'render_modal' => 'project_controls#render_modal', :as => :render_modal, :via => :get
  match 'project/:id/edit_controls' => 'projects#edit_project_controls', :as => :project_edit_controls, :via => :get
  match 'project_controls/:id/review_control' => 'project_controls#review_control', :as => :review_control, :via => :get
  match 'srg_controls/:id/review_srg_control' => 'srg_controls#review_srg_control', :as => :review_srg, :via => :get
  match 'project/:id/review_project' => 'projects#review_project', :as => :review_project, :via => :get
  match 'add_history' => 'project_control_histories#add_history', :as => :add_history, :via => :post
  match 'add_project_history' => 'project_histories#add_project_history', :as => :add_project_history, :via => :post
  match 'add_host_config' => 'host_configs#add_host_config', :as => :add_host_config, :via => :post
  match 'delete_host_config' => 'host_configs#delete_host_config', :as => :delete_host_config, :via => :post
  match 'project_controls/:id/test_controls' => 'projects#test', :as => :test, :via => :get
  match 'project_controls/:id/run_test' => 'project_controls#run_test', :as => :run_test, :via => :get
  match 'update_code' => 'project_controls#update_code', :as => :update_code, :via => :post
  match 'create_request' => 'resuests#create_request', :as => :create_request, :via => :post
  match 'project/:id/approve_project' => 'projects#approve_project', :as => :approve_project, :via => :post
  
  match 'link_control' => 'project_controls#link_control', :as => :link_control, :via => :post


  root 'dashboard#index', as: :home
end
