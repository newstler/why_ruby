# WhyRuby.info & RubyCommunity.org — Codebase Guide

This file provides guidance to AI coding agents working with this repository.

## Project Overview

WhyRuby.info is a Ruby advocacy community website built with Ruby 4.0.1 and Rails 8.2 (edge/main branch) using the Solid Stack (SQLite, SolidQueue, SolidCache, SolidCable). It features a universal content model supporting articles, links, and success stories with AI-generated summaries, GitHub OAuth authentication, community-driven content moderation, user testimonials, an interactive developer map, GitHub project tracking with star trends, and a timezone-aware newsletter system.

The app runs on two domains:
- **whyruby.info** — advocacy content and testimonials
- **rubycommunity.org** — community profiles, map, and project rankings

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

# Generate model with UUIDv7 primary key
rails generate model ModelName

# Other generators
rails generate controller ControllerName
rails generate migration MigrationName
```

## Architecture & Key Patterns

The codebase follows **37signals vanilla Rails style**: fat models with concerns, thin controllers, no service objects. All domain logic lives in models and model concerns. There is no `app/services/` directory.

### Data Model Structure

The application uses a **Universal Content Model** where the `Post` model handles three distinct content types via the `post_type` enum:

- **Articles**: Original content with markdown (`content` field required, `url` must be blank)
- **Links**: External content (`url` required, `content` must be blank)
- **Success Stories**: Ruby success stories with SVG logo (`logo_svg` and `content` required, `url` must be blank)

**Key Models:**
- `User`: GitHub OAuth authentication, role-based access (member/admin), trusted user system based on contribution counts (3+ published posts, 10+ published comments), geocoded location, timezone, newsletter tracking, profile settings (hide_repositories, open_to_work)
- `Post`: Universal content model with FriendlyId slugs, soft deletion via `archived` flag, counter caches for reports
- `Category`: Content organization with position ordering, special success story category flag
- `Tag`: HABTM relationship with posts
- `Comment`: User feedback on posts with published flag
- `Report`: Content moderation by trusted users, auto-hides after 3+ reports
- `Testimonial`: User testimonials ("why I love Ruby") with AI-generated headline, subheadline, and quote. Validated by LLM for appropriateness
- `Project`: GitHub repositories for users with star counts, language, description
- `StarSnapshot`: Daily star count snapshots per project, used to compute trending/stars gained
- `Chat`: RubyLLM chat records (`acts_as_chat`). Has a `purpose` column: `"conversation"` (default), `"summary"`, `"testimonial_generation"`, `"testimonial_validation"`. System chats (non-conversation) track AI operations for cost accounting
- `Model`: RubyLLM model records (`acts_as_model`). Tracks available AI models and their cumulative costs

### Concern Catalog

All domain logic that was previously in service objects now lives in model concerns, following the 37signals naming convention (adjective-named, namespaced to the model they belong to).

**User concerns** (`app/models/concerns/user/`):
- `User::Geocodable` — geocodes free-text locations into structured data (city, country, coordinates) via Photon API, resolves timezone from coordinates
- `User::GithubSyncable` — syncs GitHub profile data and repositories via GraphQL API on sign-in, supports batch fetching for bulk updates

**Post concerns** (`app/models/concerns/post/`):
- `Post::SvgSanitizable` — sanitizes SVG content to prevent XSS attacks in success story logos
- `Post::MetadataFetchable` — fetches OpenGraph metadata and external content from URLs for link posts
- `Post::ImageVariantable` — processes featured images into WebP variants (small, medium, large, og) via ActiveStorage
- `Post::OgImageGeneratable` — generates OG images for success stories from SVG logos
- `Post::AiSummarizable` — generates AI summary teasers via RubyLLM, creates a system chat with `purpose: "summary"`

**Testimonial concerns** (`app/models/concerns/testimonial/`):
- `Testimonial::AiGeneratable` — AI-generates headline, subheadline, and body text from user testimonial quote via RubyLLM
- `Testimonial::AiValidatable` — validates testimonial content for appropriateness via RubyLLM

**Shared concerns** (`app/models/concerns/`):
- `Costable` — cost formatting and calculation for models with a `total_cost` column (used by User, Chat, Model)

### AI Operations (RubyLLM)

All AI operations use the **RubyLLM** gem (~> 1.9), configured with `default_model: "gpt-4.1-nano"` in `config/initializers/ruby_llm.rb`.

**How AI operations work:**
1. A concern method (e.g., `Post#generate_summary!`) creates a system `Chat` record with a specific `purpose`
2. It calls `chat.ask(prompt)` which uses RubyLLM to send the request and record the response as messages
3. Message costs are tracked automatically via RubyLLM's `acts_as_chat` / `acts_as_model`
4. Per-user spending is available via the `Costable` concern on `User`

**Chat purposes:**
- `"conversation"` — default, for user-facing chats (not currently used in this app)
- `"summary"` — AI summary generation for posts
- `"testimonial_generation"` — AI headline/subheadline/body generation for testimonials
- `"testimonial_validation"` — AI content validation for testimonials

**Key pattern:** Jobs are thin delegators that call model methods. The model concern owns all the logic:
```ruby
# Job (thin delegator)
class GenerateSummaryJob < ApplicationJob
  def perform(post, force: false)
    post.generate_summary!(force: force)
  end
end

# Concern (owns the logic)
module Post::AiSummarizable
  def generate_summary!(force: false)
    chat = user.chats.create!(purpose: "summary", model: Model.find_by(...))
    response = chat.ask(prompt)
    update!(summary: clean_ai_summary(response.content))
  end
end
```

### Primary Keys & IDs

**All tables use UUIDv7 string primary keys** via the `uuid7()` SQLite function:
```ruby
create_table :table_name, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
  # ...
end
```

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

All jobs are thin delegators that call model methods. The logic lives in model concerns, not in jobs.

- `GenerateSummaryJob`: Calls `post.generate_summary!` (AI summary via `Post::AiSummarizable`)
- `GenerateSuccessStoryImageJob`: Calls `post.generate_og_image!` (OG image via `Post::OgImageGeneratable`)
- `GenerateTestimonialJob`: Calls `testimonial.generate_ai_fields!` (AI fields via `Testimonial::AiGeneratable`)
- `ValidateTestimonialJob`: Calls `testimonial.validate_with_ai!` (AI validation via `Testimonial::AiValidatable`)
- `NotifyAdminJob`: Sends notifications when content is auto-hidden
- `UpdateGithubDataJob`: Batch-syncs GitHub data via `User.batch_sync_github_data!` (from `User::GithubSyncable`)
- `NormalizeLocationJob`: Calls `user.geocode!` (geocoding via `User::Geocodable`)
- `ScheduledNewsletterJob`: Sends newsletter emails at timezone-appropriate times

### Image Processing

Posts support `featured_image` attachments via ActiveStorage. Images are processed into multiple WebP variants (small, medium, large, og) and stored as separate blobs with metadata in `image_variants` JSON column. Processing is handled by the `Post::ImageVariantable` concern.

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

Domain config lives in `config/initializers/domains.rb`. In development, community pages are served under `/community` on localhost. In production, they live at the root of rubycommunity.org (e.g. `rubycommunity.org/username`). Production routes redirect `/community/*` on the primary domain to `rubycommunity.org/*` with 301s.

**When linking to user profiles, always use `community_user_canonical_url(user)`** (or `community_root_canonical_url` for the index). These helpers resolve to the correct domain per environment. Never use `user_path`/`user_url` in user-facing links — those only produce the local `/community/...` paths.

**Cross-domain authentication**: OAuth goes through the primary domain. A cross-domain token system (`AuthController`) syncs sessions between domains. Tokens are single-use and expire in 30 seconds. The `safe_return_to` method validates redirect URLs against allowed domains.

**Footer legal links**: Use `main_site_url(path)` helper to ensure legal page links resolve to the primary domain when viewed on the community domain.

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

Always use UUIDv7 string primary keys via the `uuid7()` SQLite function. Never use auto-increment integers:

```ruby
create_table :posts, force: true, id: { type: :string, default: -> { "uuid7()" } } do |t|
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

### Code Style & Security

The project uses lefthook to run checks before commits:
- **RuboCop**: Runs with auto-fix (`-A`) on all files, fixed files are automatically staged
- **Brakeman**: Runs `bin/brakeman --no-pager` for security scanning (must pass with zero warnings)
- Configuration in `.lefthook.yml`, `.rubocop.yml`, and `config/brakeman.ignore`

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
  api_key: your_openai_api_key  # Used by RubyLLM for AI operations
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
