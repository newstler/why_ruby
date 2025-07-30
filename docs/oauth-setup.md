# GitHub OAuth Setup Guide

## Setting Up Rails Credentials

Rails credentials provide encrypted storage for sensitive data like API keys. Each environment has its own encrypted credentials file.

### Initial Setup

1. Generate a credentials file for your environment:
   ```bash
   # For development
   rails credentials:edit --environment development
   
   # For production
   rails credentials:edit --environment production
   ```

2. Add your credentials in YAML format:
   ```yaml
   github:
     client_id: your_github_oauth_client_id
     client_secret: your_github_oauth_client_secret
   
   openai:
     api_key: sk-your_openai_api_key  # Optional
   ```

3. Save and close the editor. Rails will automatically encrypt the file.

## Local Development Setup

### Step 1: Create a GitHub OAuth App

1. Go to https://github.com/settings/developers
2. Click "New OAuth App"
3. Use these settings:
   ```
   Application name: WhyRuby.info (Development)
   Homepage URL: http://localhost:3000
   Authorization callback URL: http://localhost:3000/users/auth/github/callback
   ```
4. Click "Register application"
5. Copy the Client ID and Client Secret

### Step 2: Add to Rails Credentials

```bash
rails credentials:edit --environment development
```

Add:
```yaml
github:
  client_id: your_dev_client_id_here
  client_secret: your_dev_client_secret_here

openai:
  api_key: sk-your_openai_key_here  # Optional
```

### Step 3: Test Your Setup

```bash
rails oauth:test
rails server
```

Visit http://localhost:3000 and try signing in with GitHub.

## Using ngrok (Optional)

If you need to share your local development with others or test on mobile:

1. Install ngrok:
   ```bash
   brew install ngrok  # macOS
   # Or download from https://ngrok.com
   ```

2. Start Rails and ngrok:
   ```bash
   rails server
   ngrok http 3000  # In another terminal
   ```

3. Create a new GitHub OAuth App with the ngrok URL
4. Update your development credentials with the new app's credentials

## Production Deployment

### Step 1: Create Production OAuth App

1. Create a separate GitHub OAuth App:
   ```
   Application name: WhyRuby.info
   Homepage URL: https://whyruby.info
   Authorization callback URL: https://whyruby.info/users/auth/github/callback
   ```

### Step 2: Set Production Credentials

On your production server or deployment pipeline:

```bash
EDITOR="nano" rails credentials:edit --environment production
```

Add:
```yaml
github:
  client_id: your_production_client_id
  client_secret: your_production_client_secret

openai:
  api_key: sk-your_production_openai_key

secret_key_base: your_generated_secret_key_base
```

### Step 3: Deploy

Ensure your deployment process includes:
- The master key for production (`config/credentials/production.key`)
- HTTPS is enabled (required by GitHub)

## Managing Credentials

### Viewing Current Configuration

```bash
# Check if OAuth is configured
rails oauth:test

# See example credential structure
rails oauth:example
```

### Sharing Credentials with Team

Rails credentials use a master key for encryption. To share credentials with your team:

1. Share the encrypted credentials file (safe to commit)
2. Securely share the master key file (never commit this):
   - `config/credentials/development.key`
   - `config/credentials/production.key`

### Best Practices

1. **Use separate GitHub OAuth apps** for each environment
2. **Never commit master key files** (*.key)
3. **Store production keys securely** (use environment variables for the master key)
4. **Rotate credentials regularly**
5. **Use minimal OAuth scopes** (we only need `user:email`)

## Troubleshooting

### Can't edit credentials
```bash
# Specify an editor
EDITOR="code --wait" rails credentials:edit --environment development
# Or
EDITOR="nano" rails credentials:edit --environment development
```

### OAuth redirect mismatch
- Ensure the callback URL exactly matches (including http/https)
- Check you're using the right credentials for your environment

### Missing master key
If you see "Missing encryption key" errors:
1. Check for `config/credentials/[environment].key`
2. For production, set `RAILS_MASTER_KEY` environment variable
3. Generate a new credentials file if needed

### Testing credentials
```bash
# Verify your setup
rails oauth:test

# Open Rails console to check manually
rails console
Rails.application.credentials.github
```

## Security Notes

- Rails credentials are encrypted with AES-128-GCM
- Master keys should be treated as passwords
- Each environment has its own credentials and key
- Credentials are loaded into memory when Rails starts
- Changes require a Rails restart to take effect 