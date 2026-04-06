# 37signals Style Refactor + RubyLLM Migration

## Goal

Refactor WhyRuby to follow 37signals vanilla Rails patterns (as codified in `.claude/rules/`) and switch all AI operations from raw OpenAI/Anthropic gems to RubyLLM with per-user cost tracking. Update AGENTS.md to accurately describe the project.

## Scope

1. Eliminate all service objects — move logic into model concerns
2. Migrate AI jobs from `ruby-openai`/`anthropic` gems to `ruby_llm`
3. Track per-user AI spending via existing Chat/Message infrastructure
4. Rename `GenerateTestimonialFieldsJob` to `GenerateTestimonialJob`
5. Remove `ruby-openai` and `anthropic` gems from Gemfile
6. Update AGENTS.md to reflect WhyRuby's actual architecture

---

## Part 1: Eliminate Service Objects

Move all 7 services from `app/services/` into model concerns. Delete `app/services/` directory when done.

### 1.1 `GithubDataFetcher` → `User::GithubSyncable`

**File**: `app/models/concerns/user/github_syncable.rb`

Moves all GitHub GraphQL/REST fetching logic into a User concern. The User model becomes the coordinator.

**Public interface on User**:
- `sync_github_data!` — full sync (called from `UpdateGithubDataJob`)
- `sync_github_data_from_oauth!(auth_data)` — lightweight sync from OAuth callback
- `self.batch_sync_github_data!(users)` — batch GraphQL fetch for multiple users

**Private helpers stay as private methods in the concern**:
- `graphql_request`, `build_batch_query`, `fetch_ruby_repositories`
- `update_from_graphql`, `sync_projects!`

**Job becomes thin**:
```ruby
class UpdateGithubDataJob < ApplicationJob
  def perform(users)
    User.batch_sync_github_data!(users)
  end
end
```

### 1.2 `ImageProcessor` → `Post::ImageVariantable`

**File**: `app/models/concerns/post/image_variantable.rb`

Moves image variant generation (tile/post/og WebP variants via ImageMagick) into a Post concern.

**Public interface on Post**:
- `process_image_variants!` — generates all variants from featured_image
- `image_variant(size)` — returns variant blob (already exists on Post)

**Existing Post callbacks** (`process_featured_image_if_needed`) call `process_image_variants!` directly instead of `ImageProcessor.new(self).process!`.

### 1.3 `SuccessStoryImageGenerator` → `Post::OgImageGeneratable`

**File**: `app/models/concerns/post/og_image_generatable.rb`

Moves success story OG image generation (SVG-to-WebP overlay) into a Post concern.

**Public interface on Post**:
- `generate_og_image!` — converts logo_svg to WebP, composites onto template, attaches as featured_image, then calls `process_image_variants!`

**Job becomes thin**:
```ruby
class GenerateSuccessStoryImageJob < ApplicationJob
  def perform(post)
    post.generate_og_image!
  end
end
```

### 1.4 `SvgSanitizer` → `Post::SvgSanitizable`

**File**: `app/models/concerns/post/svg_sanitizable.rb`

Moves SVG sanitization (whitelist elements/attributes, fix viewBox, remove scripts) into a Post concern.

**Public interface on Post**:
- `sanitize_logo_svg!` — sanitizes `logo_svg` in place

Called from existing `clean_logo_svg` before_validation callback. Internal helpers (`fix_svg_case_sensitivity`, `fix_viewbox_offset`, etc.) become private methods.

### 1.5 `LocationNormalizer` + `TimezoneResolver` → `User::Geocodable`

**File**: `app/models/concerns/user/geocodable.rb`

Merges location normalization (Photon API) and timezone resolution into one concern.

**Public interface on User**:
- `geocode!` — normalizes location string, sets lat/lng/normalized_location/timezone

**Job becomes thin**:
```ruby
class NormalizeLocationJob < ApplicationJob
  def perform(user)
    user.geocode!
  end
end
```

### 1.6 `MetadataFetcher` → `Post::MetadataFetchable`

**File**: `app/models/concerns/post/metadata_fetchable.rb`

Moves OpenGraph metadata fetching (title, description, image from URLs) into a Post concern.

**Public interface on Post**:
- `fetch_metadata!` — fetches OG metadata from `url`, returns hash
- `fetch_external_content` — fetches page text content (used by AI summarization)

Called from `PostsController#fetch_metadata` action and `GenerateSummaryJob`.

---

## Part 2: Migrate AI to RubyLLM + Per-User Cost Tracking

### 2.1 Strategy: System Chats for Background AI

Each AI background operation creates a Chat/Message pair attributed to the triggering user. This reuses the existing `acts_as_chat` / `acts_as_message` infrastructure for automatic token counting and cost tracking.

**Pattern**:
```ruby
# In a concern or job
chat = user.chats.create!(model: Model.find_by(model_id: "gpt-4.1-nano"))
chat.ask("prompt here")
# RubyLLM automatically populates tokens on the Message
# Message#calculate_cost fires, updating chat/user total_cost
```

We add a `purpose` column to `chats` to distinguish system-generated chats from user-initiated ones:

```ruby
# Migration
add_column :chats, :purpose, :string, default: "conversation"
add_index :chats, :purpose
```

Purposes: `"conversation"` (user chat), `"summary"`, `"testimonial_generation"`, `"testimonial_validation"`, `"translation"`.

System chats are hidden from the user's chat list via scope:
```ruby
scope :conversations, -> { where(purpose: "conversation") }
scope :system, -> { where.not(purpose: "conversation") }
```

### 2.2 `Post::AiSummarizable` concern

**File**: `app/models/concerns/post/ai_summarizable.rb`

Replaces `GenerateSummaryJob`'s raw Anthropic/OpenAI calls with RubyLLM.

**Public interface on Post**:
- `generate_summary!(force: false)` — creates system chat, asks for summary, updates post

**Job becomes thin**:
```ruby
class GenerateSummaryJob < ApplicationJob
  def perform(post, force: false)
    post.generate_summary!(force: force)
  end
end
```

**Implementation**:
- Creates a chat with `purpose: "summary"` for `post.user`
- For link posts, calls `fetch_external_content` (from `MetadataFetchable`) to get page text
- Sends single prompt via `chat.ask(prompt)`
- Cleans summary text (remove meta-language), updates `post.summary`
- Broadcasts update via Turbo Streams

### 2.3 `Testimonial::AiGeneratable` concern

**File**: `app/models/concerns/testimonial/ai_generatable.rb`

Replaces `GenerateTestimonialFieldsJob`'s raw API calls.

**Public interface on Testimonial**:
- `generate_ai_fields!` — creates system chat, generates heading/subheading/body_text

**Job renamed to `GenerateTestimonialJob`** (from `GenerateTestimonialFieldsJob`):
```ruby
class GenerateTestimonialJob < ApplicationJob
  def perform(testimonial)
    testimonial.generate_ai_fields!
  end
end
```

**Implementation**:
- Creates chat with `purpose: "testimonial_generation"` for `testimonial.user`
- Includes existing heading collision retry logic (up to 5 retries)
- On success, enqueues `ValidateTestimonialJob`

### 2.4 `Testimonial::AiValidatable` concern

**File**: `app/models/concerns/testimonial/ai_validatable.rb`

Replaces `ValidateTestimonialJob`'s raw API calls.

**Public interface on Testimonial**:
- `validate_with_ai!` — creates system chat, validates content, publishes or rejects

**Job becomes thin**:
```ruby
class ValidateTestimonialJob < ApplicationJob
  def perform(testimonial)
    testimonial.validate_with_ai!
  end
end
```

**Implementation**:
- Creates chat with `purpose: "testimonial_validation"` for `testimonial.user`
- Parses JSON response for publish/reject decision
- On rejection with reason "generation" and attempts < 3, re-enqueues `GenerateTestimonialJob`
- Broadcasts Turbo Stream update

### 2.5 Update `TranslateContentJob`

Already uses RubyLLM. Change: attribute the chat to a user with `purpose: "translation"` instead of creating a bare `RubyLLM.chat()`. The user is determined from the translatable record: if the record responds to `user`, use that; otherwise use `Current.user` or a system-level admin user as fallback (translations are team-initiated, not always user-specific).

### 2.6 Gem Cleanup

Remove from Gemfile:
- `gem "ruby-openai"`
- `gem "anthropic"`

Keep:
- `gem "ruby_llm"` (already present)

RubyLLM handles both OpenAI and Anthropic providers through its unified interface.

### 2.7 RubyLLM Model Selection

All background AI jobs use a small, cheap model. Current jobs use `claude-3-haiku` / `gpt-3.5-turbo`. With RubyLLM, standardize on `gpt-4.1-nano` (already configured as `default_model` in `config/initializers/ruby_llm.rb`). Each concern can override the model if needed.

---

## Part 3: Update AGENTS.md

Rewrite AGENTS.md to accurately describe WhyRuby instead of the template's generic SaaS. Key changes:

- **Project Overview**: WhyRuby.info / RubyCommunity.org content advocacy site
- **Authentication**: GitHub OAuth (not magic links)
- **Architecture section**: 37signals vanilla Rails, concerns over services, no service objects
- **AI section**: RubyLLM for all AI, system chats for cost tracking
- **Remove template-specific sections**: Team billing/pricing, magic link auth descriptions
- **Keep MCP section**: MCP tools/resources are functional in the codebase — document them accurately
- **Keep relevant sections**: Multi-domain setup, community features, Solid Stack, deployment
- **Add concern catalog**: List all model concerns and what they do

---

## Part 4: File Changes Summary

### New Files
- `app/models/concerns/user/github_syncable.rb`
- `app/models/concerns/user/geocodable.rb`
- `app/models/concerns/post/image_variantable.rb`
- `app/models/concerns/post/og_image_generatable.rb`
- `app/models/concerns/post/svg_sanitizable.rb`
- `app/models/concerns/post/metadata_fetchable.rb`
- `app/models/concerns/post/ai_summarizable.rb`
- `app/models/concerns/testimonial/ai_generatable.rb`
- `app/models/concerns/testimonial/ai_validatable.rb`
- `db/migrate/XXXXXX_add_purpose_to_chats.rb`

### Modified Files
- `app/models/user.rb` — include new concerns
- `app/models/post.rb` — include new concerns, remove service calls
- `app/models/testimonial.rb` — include new concerns
- `app/models/chat.rb` — add purpose scopes
- `app/jobs/generate_summary_job.rb` — thin out to delegate to concern
- `app/jobs/generate_testimonial_job.rb` — renamed, thin out
- `app/jobs/validate_testimonial_job.rb` — thin out
- `app/jobs/generate_success_story_image_job.rb` — thin out
- `app/jobs/normalize_location_job.rb` — thin out
- `app/jobs/update_github_data_job.rb` — thin out
- `app/jobs/translate_content_job.rb` — use system chat for cost tracking
- `app/controllers/posts_controller.rb` — use Post methods instead of service calls
- `app/controllers/users/omniauth_callbacks_controller.rb` — use User methods
- `Gemfile` — remove ruby-openai, anthropic
- `AGENTS.md` — full rewrite

### Deleted Files
- `app/services/github_data_fetcher.rb`
- `app/services/image_processor.rb`
- `app/services/success_story_image_generator.rb`
- `app/services/svg_sanitizer.rb`
- `app/services/location_normalizer.rb`
- `app/services/timezone_resolver.rb`
- `app/services/metadata_fetcher.rb`
- `app/services/` directory itself

### Renamed Files
- `app/jobs/generate_testimonial_fields_job.rb` → `app/jobs/generate_testimonial_job.rb`

---

## Testing Strategy

- Existing tests should continue to pass after each concern migration (same behavior, different location)
- Update test references from service class names to model method calls
- For RubyLLM migration: stub `Chat#ask` in tests instead of stubbing raw API clients
- Add tests for `purpose` scoping on Chat
- Run `rails test` after each Part to verify nothing breaks

## Migration Order

1. **Part 1 first** (service → concern migrations) — pure refactor, no behavior change
2. **Part 2 second** (AI migration) — changes AI provider interface
3. **Part 3 last** (AGENTS.md) — documentation reflects final state
