Rails.application.routes.draw do
  draw :madmin

  # GitHub OAuth routes (OmniAuth handles /auth/github via Rack middleware)
  match "auth/github/callback", to: "users/omniauth_callbacks#github", via: [ :get, :post ]
  get "auth/failure", to: "users/omniauth_callbacks#failure"
  match "sign_in_github", to: "users/sessions#github_auth", as: :github_auth_with_return, via: [ :get, :post ]
  delete "sign_out", to: "users/sessions#destroy", as: :destroy_user_session

  # Admin authentication (magic link - separate from user auth)
  namespace :admins do
    resource :session, only: [ :new, :create, :destroy ]
    get "auth/:token", to: "sessions#verify", as: :verify_magic_link
  end

  # Cross-domain auth routes (must be early)
  get "auth/receive", to: "auth#receive"
  get "auth/sign_out_receive", to: "auth#sign_out_receive"

  # Production community domain: rubycommunity.org (users at root level /:username)
  constraints host: Rails.application.config.x.domains.community do
    root "users#index", as: :rubycommunity_root
    get "map_data", to: "users#map_data", as: :rubycommunity_map_data
    get "community", to: redirect("/", status: 301)
    get "community/:id", to: redirect("/%{id}", status: 301), constraints: { id: /[^\/]+/ }
    get ":id", to: "users#show", as: :rubycommunity_user, constraints: { id: /[^\/\.]+/ }
  end

  # Litestream backup UI - only accessible to admin users
  mount Litestream::Engine, at: "/litestream"

  # Onboarding (first-time user setup, before team context)
  resource :onboarding, only: [ :show, :update ]

  # Team management (multi-tenant only routes for listing/creating teams)
  resources :teams, only: [ :index, :new, :create ], param: :slug

  # Team-scoped routes
  scope "/t/:team_slug", as: :team do
    root "home#index", as: :root
    resources :chats do
      resources :messages, only: [ :create ]
    end
    resources :models, only: [ :index, :show ]
    resource :models_refresh, only: [ :create ], controller: "models/refreshes"

    # Team settings (multi-tenant only)
    resource :settings, only: [ :show, :edit, :update ], controller: "teams/settings" do
      patch :regenerate_api_key
    end
    resource :name_check, only: [ :show ], controller: "teams/name_checks"
    resources :members, only: [ :index, :show, :new, :create, :destroy ], controller: "teams/members"
    resource :profile, only: [ :show, :edit, :update ], controller: "profiles"

    # Content
    resources :articles
    resources :languages, only: [ :index, :create, :destroy ], controller: "teams/languages"

    # Billing
    resource :pricing, only: [ :show ], controller: "teams/pricing"
    resource :billing, only: [ :show ], controller: "teams/billing"
    resource :checkout, only: [ :create ], controller: "teams/checkouts"
    resource :subscription_cancellation, only: [ :create, :destroy ], controller: "teams/subscription_cancellations"
  end

  # Webhooks
  namespace :webhooks do
    resource :stripe, only: [ :create ], controller: "stripe"
  end

  # OG Image preview page (screenshot at 1200x630 for social sharing)
  get "og-image", to: "og_images#show"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # In production, redirect /community paths on primary domain to rubycommunity.org
  if Rails.env.production?
    community_domain = Rails.application.config.x.domains.community
    primary_host = { host: Rails.application.config.x.domains.primary }
    get "community", to: redirect("https://#{community_domain}/", status: 301), constraints: primary_host
    get "community/:id", to: redirect("https://#{community_domain}/%{id}", status: 301), constraints: primary_host
  end

  # Community routes — local development fallback for rubycommunity.org (see domain constraint above)
  get "community", to: "users#index", as: :users
  get "community/map_data", to: "users#map_data", as: :community_map_data
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

  # Testimonials (singular resource - one per user)
  resource :testimonial, only: [ :create, :update ]

  # User settings routes
  resource :user_settings, only: [], controller: "user_settings" do
    post :toggle_public, on: :collection
    post :toggle_open_to_work, on: :collection
    post :toggle_newsletter, on: :collection
    post :hide_repo, on: :collection
    post :unhide_repo, on: :collection
  end

  # Newsletter unsubscribe
  get "newsletter/unsubscribe/:token", to: "newsletter_unsubscribes#show", as: :newsletter_unsubscribe
  get "newsletter/open/:token", to: "newsletter_opens#show", as: :newsletter_open

  # OG image preview pages (for screenshotting)
  get "og-image-community", to: "users#og_image"

  # Legal pages (must be before catch-all routes)
  get "legal/privacy", to: "legal#show", defaults: { page: "privacy_policy" }, as: :privacy_policy
  get "legal/terms", to: "legal#show", defaults: { page: "terms_of_service" }, as: :terms_of_service
  get "legal/cookies", to: "legal#show", defaults: { page: "cookie_policy" }, as: :cookie_policy
  get "legal", to: "legal#show", defaults: { page: "legal_notice" }, as: :legal_notice

  # Category routes (must be at the end due to catch-all nature)
  # Exclude paths with dots so file requests (sitemap.xml, robots.txt) fall through to public/
  get ":id", to: "categories#show", as: :category, constraints: { id: /[^\/\.]+/ }

  # Post routes (must be after category)
  get ":category_id/:id", to: "posts#show", as: :post, constraints: { category_id: /[^\/\.]+/, id: /[^\/\.]+/ }
  get ":category_id/:id/og-image.webp", to: "posts#image", as: :post_image, constraints: { category_id: /[^\/]+/, id: /[^\/]+/ }

  # Test-only route for setting session in integration tests
  if Rails.env.test?
    post "/_test_sign_in", to: ->(env) {
      request = Rack::Request.new(env)
      env["rack.session"][:user_id] = request.params["user_id"]
      [ 200, { "Content-Type" => "text/plain" }, [ "OK" ] ]
    }
  end

  # Defines the root path route ("/")
  root "home#index"
end
