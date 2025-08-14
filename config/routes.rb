Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  # Add sign out route for OmniAuth-only authentication
  devise_scope :user do
    delete "sign_out", to: "users/sessions#destroy", as: :destroy_user_session
    match "sign_in_github", to: "users/sessions#github_auth", as: :github_auth_with_return, via: [ :get, :post ]
  end

  # Admin panel - only accessible to users with admin role
  authenticate :user, ->(user) { user.admin? } do
    mount Avo::Engine, at: Avo.configuration.root_path
    mount Litestream::Engine, at: "/litestream"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Community routes
  get "community", to: "users#index", as: :users
  get "community/:id", to: "users#show", as: :user

  # Tags route (keeping as resources for now)
  resources :tags, only: [ :show ] do
    collection do
      get :search
    end
  end

  # Post collection actions (preview, metadata, etc)
  post "posts/preview", to: "posts#preview", as: :preview_posts
  post "posts/fetch_metadata", to: "posts#fetch_metadata", as: :fetch_metadata_posts
  post "posts/check_duplicate_url", to: "posts#check_duplicate_url", as: :check_duplicate_url_posts

  # New and edit routes for posts (need to be defined before dynamic routes)
  get "posts/new", to: "posts#new", as: :new_post
  get "posts/:id/edit", to: "posts#edit", as: :edit_post
  post "posts", to: "posts#create", as: :posts
  patch "posts/:id", to: "posts#update", as: :post_update
  put "posts/:id", to: "posts#update"
  delete "posts/:id", to: "posts#destroy", as: :post_destroy

  # Comments and reports for posts
  post "posts/:post_id/comments", to: "comments#create", as: :post_comments
  delete "posts/:post_id/comments/:id", to: "comments#destroy", as: :post_comment
  post "posts/:post_id/reports", to: "reports#create", as: :post_reports

  # Legal pages (must be before catch-all routes)
  get "legal/privacy", to: "legal#show", defaults: { page: "privacy_policy" }, as: :privacy_policy
  get "legal/terms", to: "legal#show", defaults: { page: "terms_of_service" }, as: :terms_of_service
  get "legal/cookies", to: "legal#show", defaults: { page: "cookie_policy" }, as: :cookie_policy
  get "legal", to: "legal#show", defaults: { page: "legal_notice" }, as: :legal_notice

  # Category routes (must be at the end due to catch-all nature)
  get ":id", to: "categories#show", as: :category, constraints: { id: /[^\/]+/ }

  # Post routes (must be after category)
  get ":category_id/:id", to: "posts#show", as: :post, constraints: { category_id: /[^\/]+/, id: /[^\/]+/ }
  get ":category_id/:id/og-image.webp", to: "posts#image", as: :post_image, constraints: { category_id: /[^\/]+/, id: /[^\/]+/ }

  # Defines the root path route ("/")
  root "home#index"
end
