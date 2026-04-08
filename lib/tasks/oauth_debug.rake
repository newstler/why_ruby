namespace :oauth do
  desc "Debug OAuth configuration"
  task debug: :environment do
    puts "\n🔍 OAuth Debug Information\n"
    puts "="*50

    puts "\n1. GitHub Credentials (from Settings):"
    puts "   WhyRuby Client ID: #{Setting.get(:github_whyruby_client_id).present? ? '[PRESENT]' : '[MISSING]'}"
    puts "   WhyRuby Client Secret: #{Setting.get(:github_whyruby_client_secret).present? ? '[PRESENT]' : '[MISSING]'}"
    puts "   RubyCommunity Client ID: #{Setting.get(:github_rubycommunity_client_id).present? ? '[PRESENT]' : '[MISSING]'}"
    puts "   RubyCommunity Client Secret: #{Setting.get(:github_rubycommunity_client_secret).present? ? '[PRESENT]' : '[MISSING]'}"
    puts "   API Token: #{Setting.get(:github_api_token).present? ? '[PRESENT]' : '[MISSING]'}"

    puts "\n2. Routes:"
    routes = Rails.application.routes.routes.select { |r| r.path.spec.to_s.include?("github") }
    routes.each do |route|
      puts "   #{route.verb.ljust(8)} #{route.path.spec.to_s.ljust(35)} => #{route.defaults[:controller]}##{route.defaults[:action]}"
    end

    puts "\n3. Middleware Stack (Omniauth related):"
    Rails.application.config.middleware.each do |middleware|
      if middleware.to_s.include?("OmniAuth") || middleware.to_s.include?("Warden")
        puts "   ✓ #{middleware}"
      end
    end

    puts "\n4. Test URLs for port 3003:"
    puts "   Sign in:  http://localhost:3003/auth/github"
    puts "   Callback: http://localhost:3003/auth/github/callback"

    puts "\n5. Common Issues:"
    puts "   ❌ 'Authentication passthru' = Middleware not loaded (restart server)"
    puts "   ❌ 'Redirect mismatch' = Check GitHub app callback URL"
    puts "   ❌ 'CSRF token' = Check session store configuration"

    puts "\n✅ Next steps:"
    puts "   1. Ensure GitHub OAuth app uses: http://localhost:3003/auth/github/callback"
    puts "   2. Restart Rails server: bin/dev"
    puts "   3. Clear browser cookies for localhost"
    puts "   4. Try signing in again\n"
  end
end
