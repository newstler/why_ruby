namespace :credentials do
  desc "Initialize credentials for all environments"
  task init: :environment do
    puts "\n🔧 Initializing Rails Credentials\n"
    puts "="*50

    environments = %w[development test production]

    environments.each do |env|
      puts "\n#{env.capitalize} environment:"

      key_path = Rails.root.join("config", "credentials", "#{env}.key")
      enc_path = Rails.root.join("config", "credentials", "#{env}.yml.enc")

      if File.exist?(enc_path)
        puts "  ✅ Credentials file already exists"
      else
        puts "  📝 Creating new credentials file..."
        puts "     Run: rails credentials:edit --environment #{env}"
        puts "     This will create both the encrypted file and master key"
      end

      if File.exist?(key_path)
        puts "  🔑 Master key exists"
      else
        puts "  ⚠️  Master key will be created when you edit credentials"
      end
    end

    puts "\n\n📋 Next steps:"
    puts "1. Edit credentials for your current environment:"
    puts "   rails credentials:edit --environment #{Rails.env}"
    puts "\n2. Add your OAuth credentials following this structure:"
    puts "   github:"
    puts "     client_id: your_client_id"
    puts "     client_secret: your_client_secret"
    puts "\n3. Test your configuration:"
    puts "   rails oauth:test"

    puts "\n⚠️  Remember: Never commit .key files to version control!"
    puts "The .gitignore file should already exclude them.\n"
  end

  desc "Show current credentials (redacted)"
  task show: :environment do
    puts "\n🔍 Current Rails Credentials (#{Rails.env})\n"
    puts "="*50

    begin
      creds = Rails.application.credentials.config

      if creds.present?
        puts "\nAvailable top-level keys:"
        creds.keys.each do |key|
          value = creds[key]
          if value.is_a?(Hash)
            puts "  #{key}:"
            value.keys.each do |subkey|
              puts "    #{subkey}: [REDACTED]"
            end
          else
            puts "  #{key}: [REDACTED]"
          end
        end
      else
        puts "\n❌ No credentials found for #{Rails.env} environment"
        puts "   Run: rails credentials:edit --environment #{Rails.env}"
      end
    rescue => e
      puts "\n❌ Error reading credentials: #{e.message}"
      puts "   This usually means the credentials file doesn't exist yet."
      puts "   Run: rails credentials:edit --environment #{Rails.env}"
    end
  end
end
