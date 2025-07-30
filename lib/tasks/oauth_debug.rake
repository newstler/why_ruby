namespace :oauth do
  desc "Debug OAuth configuration"
  task debug: :environment do
    puts "\n🔍 OAuth Debug Information\n"
    puts "="*50
    
    puts "\n1. GitHub Credentials:"
    puts "   Client ID: #{Rails.application.credentials.dig(:github, :client_id)}"
    puts "   Client Secret: #{Rails.application.credentials.dig(:github, :client_secret).present? ? '[PRESENT]' : '[MISSING]'}"
    
    puts "\n2. Devise Configuration:"
    puts "   Omniauth providers: #{Devise.omniauth_providers}"
    puts "   Omniauth path prefix: #{Devise.omniauth_path_prefix}"
    
    puts "\n3. Routes:"
    routes = Rails.application.routes.routes.select { |r| r.path.spec.to_s.include?('github') }
    routes.each do |route|
      puts "   #{route.verb.ljust(8)} #{route.path.spec.to_s.ljust(35)} => #{route.defaults[:controller]}##{route.defaults[:action]}"
    end
    
    puts "\n4. Middleware Stack (Omniauth related):"
    Rails.application.config.middleware.each do |middleware|
      if middleware.to_s.include?('OmniAuth') || middleware.to_s.include?('Warden')
        puts "   ✓ #{middleware}"
      end
    end
    
    puts "\n5. Test URLs for port 3003:"
    puts "   Sign in:  http://localhost:3003/users/auth/github"
    puts "   Callback: http://localhost:3003/users/auth/github/callback"
    
    puts "\n6. Common Issues:"
    puts "   ❌ 'Authentication passthru' = Middleware not loaded (restart server)"
    puts "   ❌ 'Redirect mismatch' = Check GitHub app callback URL"
    puts "   ❌ 'CSRF token' = Check session store configuration"
    
    puts "\n✅ Next steps:"
    puts "   1. Ensure GitHub OAuth app uses: http://localhost:3003/users/auth/github/callback"
    puts "   2. Restart Rails server: rails server -p 3003"
    puts "   3. Clear browser cookies for localhost"
    puts "   4. Try signing in again\n"
  end
end 