# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WhyRuby.info is a Ruby advocacy community website built with Rails 8.1 (edge/main branch) and the Solid Stack (SQLite, SolidQueue, SolidCache, SolidCable). It features a universal content model supporting articles, links, and success stories with AI-generated summaries, GitHub OAuth authentication, and community-driven content moderation.

## Development Commands

### Server Management
```bash
# Start the development server (REQUIRED - do not use rails server directly)
bin/dev

# Monitor logs in real-time
tail -f log/development.log
```

**IMPORTANT**: Always use `bin/dev` instead of `rails server`. This starts both the Rails server (port 3003) and Tailwind CSS watcher via Procfile.dev.

### Database
```bash
# Create and setup database
rails db:create
rails db:migrate
rails db:seed

# Database console
rails db

# Promote user to admin
rails runner "User.find_by(username: 'github-username').update!(role: :admin)"
```

### Testing & Code Quality
```bash
# Run all tests
rails test

# Run single test file
rails test test/models/post_test.rb

# Run single test
rails test test/models/post_test.rb:line_number

# Code style (auto-fixes and stages changes via lefthook)
bundle exec rubocop
bundle exec rubocop -A  # Auto-correct issues
```

### Rails Console & Generators
```bash
# Console
rails console

# Generate model with ULID primary key
rails generate model ModelName

# Other generators
rails generate controller ControllerName
rails generate migration MigrationName
```

## Architecture & Key Patterns

### Data Model Structure

The application uses a **Universal Content Model** where the `Post` model handles three distinct content types via the `post_type` enum:

- **Articles**: Original content with markdown (`content` field required, `url` must be blank)
- **Links**: External content (`url` required, `content` must be blank)
- **Success Stories**: Ruby success stories with SVG logo (`logo_svg` and `content` required, `url` must be blank)

**Key Models:**
- `User`: GitHub OAuth authentication, role-based access (member/admin), trusted user system based on contribution counts (3+ published posts, 10+ published comments)
- `Post`: Universal content model with FriendlyId slugs, soft deletion via `archived` flag, counter caches for reports
- `Category`: Content organization with position ordering, special success story category flag
- `Tag`: HABTM relationship with posts
- `Comment`: User feedback on posts with published flag
- `Report`: Content moderation by trusted users, auto-hides after 3+ reports

### Primary Keys & IDs

**All tables use ULID instead of integer IDs:**
```ruby
create_table :table_name, force: true, id: false do |t|
  t.primary_key :id, :string, default: -> { "ULID()" }
  # ...
end
```

This is configured via the `sqlite-ulid` gem and provides better distribution and sortability.

### Authentication & Authorization

- **Authentication**: GitHub OAuth only via Devise + OmniAuth
- **Roles**: `member` (default) and `admin` (enum in User model)
- **Trusted Users**: Automatically qualified when `published_posts_count >= 3` AND `published_comments_count >= 10`
- **Permissions**: Only trusted users can report content; only admins can access `/admin` (Avo panel)

### Content Moderation Flow

1. Trusted users can report inappropriate content
2. After 3+ reports, content is automatically:
   - Set to `published: false`
   - Flagged with `needs_admin_review: true`
   - Admin notification sent via `NotifyAdminJob`
3. Admins review and restore or permanently archive via Avo panel

### Background Jobs (SolidQueue)

- `GenerateSummaryJob`: Creates AI summaries for new/updated posts using OpenAI or Anthropic APIs
- `GenerateSuccessStoryImageJob`: Generates OG images for success stories from SVG logos
- `NotifyAdminJob`: Sends notifications when content is auto-hidden
- `UpdateGithubDataJob`: Refreshes user GitHub data (repositories, stars, etc.)

### Image Processing

Posts support `featured_image` attachments via ActiveStorage. Images are processed into multiple variants (small, medium, large, og) and stored as separate blobs with metadata in `image_variants` JSON column. Processing uses the `ImageProcessor` service.

### URL Routing Pattern

The application uses a **catch-all routing strategy** for clean URLs:

```
/:category_slug              # Category pages
/:category_slug/:post_slug   # Post pages
```

**Important**: Category and post routes use constraints and are defined at the END of routes.rb to avoid conflicts with explicit routes like `/admin`, `/community`, `/legal/*`, etc.

### Multi-Domain Setup (Community)

The app runs on two domains:
- **whyruby.info** — main content site
- **rubycommunity.org** — community/user profiles (production only)

In development, community pages are served under `/community` on localhost. In production, they live at the root of rubycommunity.org (e.g. `rubycommunity.org/username`).

**When linking to user profiles, always use `community_user_canonical_url(user)`** (or `community_root_canonical_url` for the index). These helpers resolve to the correct domain per environment. Never use `user_path`/`user_url` in user-facing links — those only produce the local `/community/...` paths.

### Services Layer

Service objects in `app/services/` handle complex operations:
- `GithubDataFetcher`: Fetches and updates user GitHub profile data and repositories on sign-in
- `ImageProcessor`: Processes featured images into multiple variants (small, medium, large, og)
- `SuccessStoryImageGenerator`: Generates OG images for success stories from SVG logos
- `SvgSanitizer`: Sanitizes SVG content to prevent XSS attacks

### FriendlyId Implementation

Both `User` and `Post` models use FriendlyId with history:
- `User`: Slugs from `username`
- `Post`: Slugs from `title`

Both models implement `create_slug_history` to manually save old slugs when changed, ensuring historical URLs redirect properly.

## Rails 8 Specific Patterns

### Solid Stack Usage

- **SolidQueue**: Default background job processor (no Redis needed)
- **SolidCache**: Database-backed caching
- **SolidCable**: WebSocket functionality via SQLite
- Configuration files: `config/queue.yml`, `config/cache.yml`, `config/cable.yml`

### Modern Rails 8 Conventions

- Use `params.expect()` for parameter handling instead of strong parameters (Rails 8.1 feature)
- Propshaft for asset pipeline (not Sprockets)
- Tailwind CSS 4 via `tailwindcss-rails` gem
- Hotwire (Turbo + Stimulus) for frontend interactivity

### Migrations

Always use ULID primary keys. Never use auto-increment integers:

```ruby
create_table :posts, force: true, id: false do |t|
  t.primary_key :id, :string, default: -> { "ULID()" }
  t.string :title, null: false
  # ...
end
```

## Important Development Practices

### Server & Logging

- **ALWAYS** use `bin/dev` to start the server
- Check logs after every significant change
- Monitor `log/development.log` for errors and performance issues
- Review logs before considering any change complete

### Code Style

The project uses lefthook to automatically run RuboCop before commits:
- RuboCop runs with auto-fix (`-A`) on all files
- Fixed files are automatically staged
- Configuration in `.lefthook.yml` and `.rubocop.yml`

### Testing

- Framework: Minitest (Rails default)
- Fixtures in `test/fixtures/`
- Test structure: `test/models/`, `test/controllers/`, `test/system/`
- Run tests before committing

## Credentials & Configuration

### Development Credentials

```bash
rails credentials:edit --environment development
```

Required credentials:
```yaml
github:
  client_id: your_github_oauth_app_client_id
  client_secret: your_github_oauth_app_client_secret

openai:
  api_key: your_openai_api_key  # Optional - for AI summaries
```

### GitHub OAuth Setup

1. Create OAuth App at: https://github.com/settings/developers
2. Set callback URL: `http://localhost:3000/users/auth/github/callback`
3. Add credentials to development credentials file

### GeoLite2 Database (for analytics country tracking)

The GeoLite2 database is used for IP geolocation (analytics country code). It's not redistributable, so it's gitignored and downloaded during Docker build.

**Development setup:**
1. Create a free MaxMind account: https://www.maxmind.com/en/geolite2/signup
2. Generate a license key: https://www.maxmind.com/en/accounts/current/license-key
3. Download GeoLite2-Country database and place at: `db/GeoLite2-Country.mmdb`

**Production setup:**
Add to production credentials (`rails credentials:edit --environment production`):
```yaml
maxmind:
  account_id: your_account_id  # Find at top of MaxMind license key page
  license_key: your_license_key
```

The Dockerfile automatically downloads the database during build if both `MAXMIND_ACCOUNT_ID` and `MAXMIND_LICENSE_KEY` are provided. Note: MaxMind API changed in May 2024 to require both credentials.

### Deployment

- Configured for Kamal 2 deployment (see `config/deploy.yml`)
- Litestream for SQLite backups to S3 (see `config/litestream.yml`)
- RorVsWild for performance monitoring (see `config/rorvswild.yml`)

## Admin Panel

- Admin panel powered by Avo (v3.2+)
- Route: `/admin` (only accessible to admin users)
- Configuration: `app/avo/` directory
- Litestream backup UI: `/litestream` (admin only)

## Markdown Rendering

- Redcarpet for markdown parsing
- Rouge for syntax highlighting
- Markdown content stored in `Post#content` field for articles and success stories
- Custom helper: `ApplicationHelper#render_markdown_with_syntax_highlighting`
