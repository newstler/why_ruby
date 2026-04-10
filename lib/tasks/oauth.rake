namespace :oauth do
  desc "Display OAuth setup instructions"
  task setup: :environment do
    puts "\n🔐 GitHub OAuth Setup Instructions\n"
    puts "="*50

    puts "\n1. Create a GitHub OAuth App:"
    puts "   Visit: https://github.com/settings/developers"
    puts "   Click: 'New OAuth App'"

    puts "\n2. For LOCAL development, use these settings:"
    puts "   Application name:    WhyRuby.info (Development)"
    puts "   Homepage URL:        http://localhost:3000"
    puts "   Callback URL:        http://localhost:3000/users/auth/github/callback"

    puts "\n3. For PRODUCTION, use these settings:"
    puts "   Application name:    WhyRuby.info"
    puts "   Homepage URL:        https://your-domain.com"
    puts "   Callback URL:        https://your-domain.com/users/auth/github/callback"

    puts "\n4. Add credentials via Madmin admin panel:"
    puts "   Go to /madmin/settings and fill in the GitHub section"

    puts "\n✅ Done! Start your server with 'bin/dev'\n"
  end

  desc "Test OAuth configuration"
  task test: :environment do
    puts "\n🔍 Testing OAuth Configuration...\n"

    client_id = Setting.get(:github_whyruby_client_id)
    client_secret = Setting.get(:github_whyruby_client_secret)
    api_token = Setting.get(:github_api_token)

    puts "Environment: #{Rails.env}"

    if client_id.present? && client_secret.present?
      puts "✅ GitHub OAuth (WhyRuby) is configured!"
      puts "   Client ID: #{client_id[0..7]}..."
    else
      puts "❌ GitHub OAuth (WhyRuby) is NOT configured!"
      puts "   Missing: #{'Client ID' unless client_id.present?} #{'Client Secret' unless client_secret.present?}"
      puts "\n   Configure at /madmin/settings"
    end

    community_id = Setting.get(:github_rubycommunity_client_id)
    community_secret = Setting.get(:github_rubycommunity_client_secret)

    if community_id.present? && community_secret.present?
      puts "✅ GitHub OAuth (RubyCommunity) is configured!"
      puts "   Client ID: #{community_id[0..7]}..."
    else
      puts "⚠️  GitHub OAuth (RubyCommunity) is NOT configured (optional for development)"
    end

    if api_token.present?
      puts "✅ GitHub API Token is configured!"
      puts "   Token: #{api_token[0..7]}..."
    else
      puts "⚠️  GitHub API Token is NOT configured (needed for batch sync)"
    end

    puts "\nTo edit: /madmin/settings"
  end
end
