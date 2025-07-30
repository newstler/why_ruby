Rails.application.config.middleware.use OmniAuth::Builder do
  # This is needed to fix the "Authentication passthru" error
  # The actual provider config is in devise.rb
end

# Fix for Omniauth POST requests
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true 