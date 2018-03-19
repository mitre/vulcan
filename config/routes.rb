Rails.application.routes.draw do
  resources :srg
  match 'upload_srg' => 'srg#upload', :as => :upload_srg, :via => :post

  root "pages#index"
end
