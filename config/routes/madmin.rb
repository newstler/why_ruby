# Below are the routes for madmin
namespace :madmin do
  namespace :active_storage do
    resources :variant_records
  end
  namespace :active_storage do
    resources :attachments
  end
  namespace :active_storage do
    resources :blobs
  end
  resources :admins do
    member do
      post :send_magic_link
    end
  end
  resources :chats do
    collection do
      patch :toggle_public_chats
    end
  end
  resources :messages
  resources :models do
    collection do
      post :refresh_all
    end
  end
  resources :tool_calls
  resources :users
  resources :teams

  # Content management
  resources :posts
  resources :categories
  resources :comments
  resources :reports
  resources :tags
  resources :testimonials
  resources :projects

  resources :languages do
    collection do
      post :sync
    end
    member do
      patch :toggle
    end
  end
  resource :settings, only: [ :show, :edit, :update ] do
    resource :ai_models, only: [ :show, :edit, :update ], controller: "settings/ai_models"
  end
  resources :providers, only: [ :index ] do
    collection do
      patch :update
    end
  end
  resource :prices, only: [ :show ] do
    post :sync, on: :member
  end
  resource :mail, only: [ :show, :edit, :update ], controller: "mail"
  root to: "dashboard#show"
end
