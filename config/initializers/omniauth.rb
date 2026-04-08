Rails.application.config.middleware.use OmniAuth::Builder do
  provider :github,
    nil, # Set dynamically via setup
    nil, # Set dynamically via setup
    scope: "user:email,read:user",
    callback_path: "/auth/github/callback",
    setup: lambda { |env|
      request = Rack::Request.new(env)
      strategy = env["omniauth.strategy"]

      domains = Rails.application.config.x.domains
      if Rails.env.production? && request.host == domains.community
        strategy.options[:client_id] = Setting.get(:github_rubycommunity_client_id)
        strategy.options[:client_secret] = Setting.get(:github_rubycommunity_client_secret)
        strategy.options[:callback_url] = "https://#{domains.community}/auth/github/callback"
      else
        strategy.options[:client_id] = Setting.get(:github_whyruby_client_id)
        strategy.options[:client_secret] = Setting.get(:github_whyruby_client_secret)
        strategy.options[:callback_url] = Rails.env.production? ? "https://#{domains.primary}/auth/github/callback" : nil
      end
    }
end

OmniAuth.config.allowed_request_methods = [ :post, :get ]
OmniAuth.config.silence_get_warning = true
