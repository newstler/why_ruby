Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
  
  # Add sign out route for OmniAuth-only authentication
  devise_scope :user do
    delete 'sign_out', to: 'users/sessions#destroy', as: :destroy_user_session
  end
  
  # Admin panel - only accessible to users with admin role
  authenticate :user, ->(user) { user.admin? } do
    mount Avo::Engine, at: Avo.configuration.root_path
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :posts do
    resources :comments, only: [:create, :destroy]
    resources :reports, only: [:create]
    
    collection do
      post :preview
      post :fetch_metadata
      post :check_duplicate_url
    end
  end
  
  resources :categories, only: [:show]
  resources :tags, only: [:show]
  
  # User profile
  resources :users, only: [:show]
  
  # Defines the root path route ("/")
  root "posts#index"
end
