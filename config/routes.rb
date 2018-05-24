Rails.application.routes.draw do
  resources :project_controls
  resources :projects
  resources :srg_controls
  resources :srgs
  resources :srg
  resources :pages
  match 'upload_srg' => 'srgs#upload', :as => :upload_srg, :via => :post
  match 'upload_project' => 'projects#upload', :as => :upload_project, :via => :post

  root "srgs#index"
end
