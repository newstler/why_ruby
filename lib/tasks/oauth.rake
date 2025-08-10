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

    puts "\n4. Add credentials to Rails:"
    puts "   For development: rails credentials:edit --environment development"
    puts "   For production:  rails credentials:edit --environment production"
    puts "   For test:        rails credentials:edit --environment test"

    puts "\n   Add this structure:"
    puts "   github:"
    puts "     client_id: your_client_id"
    puts "     client_secret: your_client_secret"
    puts "   openai:"
    puts "     api_key: your_openai_key (optional)"

    puts "\n✅ Done! Start your server with 'rails server'\n"
  end

  desc "Test OAuth configuration"
  task test: :environment do
    puts "\n🔍 Testing OAuth Configuration...\n"

    client_id = Rails.application.credentials.dig(:github, :client_id)
    client_secret = Rails.application.credentials.dig(:github, :client_secret)
    openai_key = Rails.application.credentials.dig(:openai, :api_key)

    puts "Environment: #{Rails.env}"
    puts "Credentials file: config/credentials/#{Rails.env}.yml.enc"

    if client_id.present? && client_secret.present?
      puts "✅ GitHub OAuth is configured!"
      puts "   Client ID: #{client_id[0..7]}..." if client_id
    else
      puts "❌ GitHub OAuth is NOT configured!"
      puts "   Missing: #{'Client ID' unless client_id.present?} #{'Client Secret' unless client_secret.present?}"
      puts "\n   Run 'rails oauth:setup' for instructions"
    end

    if openai_key.present?
      puts "✅ OpenAI API is configured!"
      puts "   API Key: #{openai_key[0..7]}..."
    else
      puts "⚠️  OpenAI API is NOT configured (optional)"
    end

    puts "\nTo edit credentials:"
    puts "  rails credentials:edit --environment #{Rails.env}"
  end

  desc "Show example credentials structure"
  task example: :environment do
    puts "\n📝 Example Rails Credentials Structure\n"
    puts "="*50
    puts <<~YAML
      # config/credentials/development.yml.enc
      # (or production.yml.enc, test.yml.enc)

      github:
        client_id: your_github_oauth_client_id_here
        client_secret: your_github_oauth_client_secret_here

      openai:
        api_key: sk-your_openai_api_key_here

      # You can also add other credentials here:
      secret_key_base: generated_secret_key_base
    YAML

    puts "\nTo edit: rails credentials:edit --environment #{Rails.env}"
  end
end
