# Idea: RAG Chatbot ("Ask about Ruby")

A small chatbot on the homepage where visitors can learn about Ruby, augmented with our own content (Posts, Testimonials, Projects) via vector search.

## Goals

- Add a simple "Ask about Ruby" experience to the homepage
- Gain experience with vector search using SQLite (no separate DB)
- Reuse existing chat infrastructure (Chat/Message models, views, streaming)
- Keep costs bounded and prevent abuse as a free general-purpose AI

## UX

- **Homepage**: a single input field ("Ask about Ruby...") with a send button — no full chat widget
- **Homepage nav**: new "Chat" link alongside existing category buttons and "Community"
- **`/chat` page**: reuses the existing beautiful chat view (from the remote template), requires login
- **Single chat per user** — no chat list, no "new chat" button, no multi-tenant URLs exposed to users
- **Auth gate**: hitting send on the homepage, or navigating to `/chat`, triggers GitHub OAuth if not signed in, then lands on `/chat` with the question submitted

## Cost control — single rotating chat

A single ever-growing chat would get expensive fast because RubyLLM's `acts_as_chat` sends full conversation history on every request.

**Strategy:** one active chat per user, silently rotated:

- Always show "the user's current chat" at `/chat`
- If the current chat exceeds ~30 messages or is older than 24h, start a new one behind the scenes
- Old chats stay in the DB for cost tracking but the user never sees them
- From the user's perspective it feels like one continuous conversation

## Topic restriction

Restrict conversations to Ruby / our site content via the system prompt. No code-level topic detection — the LLM enforces this. If a question isn't about Ruby, the Ruby ecosystem, or content on our site, politely decline and redirect.

## Architecture: RAG with SQLite vector search

### Stack

| Layer | Tool | Notes |
|-------|------|-------|
| Vector storage | `sqlite-vec` gem | SQLite extension, no separate DB |
| Rails integration | `neighbor` gem | Andrew Kane — `has_neighbors`, `nearest_neighbors` |
| Embeddings | `RubyLLM.embed` | Already have `ruby_llm` |
| Chat + streaming | Existing `Chat`/`Message` + `ChatResponseJob` + Turbo Streams | Full reuse |

Two new gems: `sqlite-vec`, `neighbor`. Everything else already in the project.

### Flow

```
User question
     │
     ▼
 ① RubyLLM.embed(question)  →  query vector (1536 floats)
     │
     ▼
 ② ContentChunk.nearest_neighbors(:embedding, vector, distance: "cosine").first(8)
     │
     ▼
 ③ Build system prompt with retrieved chunks + Ruby-only instructions
     │
     ▼
 ④ chat.ask(question)  →  streamed response via existing Turbo Streams
```

### Data model

**Two new tables:**

```ruby
# vec0 virtual table — stores only vectors + IDs
create_virtual_table :content_embeddings, :vec0, [
  "id text PRIMARY KEY NOT NULL",
  "embedding float[1536] distance_metric=cosine"
]

# Metadata table — stores text chunks + polymorphic source reference
create_table :content_chunks, id: { type: :string, default: -> { "uuid7()" } } do |t|
  t.string :source_type, null: false  # "Post", "Testimonial", "Project"
  t.string :source_id, null: false
  t.text :content, null: false
  t.string :title
  t.timestamps
end
```

### Content indexed

| Model | Fields embedded |
|-------|----------------|
| **Post** (published) | `title + summary + content_or_url` |
| **Testimonial** (published) | `heading + quote + body_text` |
| **Project** (visible) | `name + description + topics` |

### New concerns

**`Embeddable`** — shared by Post, Testimonial, Project. Each model defines `embeddable_text`. Callbacks trigger `GenerateEmbeddingJob` on save.

**`Chat::RagAugmentable`** — added to Chat. Provides `ask_with_rag(question, &block)`:
1. Generates query embedding via `RubyLLM.embed`
2. Finds nearest 8 `ContentChunk` records
3. Builds system prompt with retrieved context + Ruby-only instructions
4. Calls `ask(question, with_instructions: system_prompt, &block)`

### Chat purpose

Add `"rag"` to existing purposes (`conversation`, `summary`, `testimonial_generation`, `testimonial_validation`). `ChatResponseJob` detects `purpose == "rag"` and calls `ask_with_rag`.

### Settings (no hardcoded models)

Add `embedding_model` to `Setting::ALLOWED_KEYS`, default `"text-embedding-3-small"` (1536 dims). Configurable via the existing Madmin settings page, same pattern as `summary_model`, `testimonial_model`, etc.

## Routes

```ruby
# Top-level, no team slug exposed
resource :chat, only: [:show, :create], controller: "chats"
```

- `GET /chat` — shows user's current chat (creates one if none), requires auth
- `POST /chat` — sends a message, requires auth
- Homepage input form posts to `/chat`

## Auth flow

The existing `authenticate_user!` in `ApplicationController` already handles the redirect:

```ruby
def authenticate_user!
  unless user_signed_in?
    session[:return_to] = request.original_url if request.get?
    redirect_to github_auth_with_return_path, alert: "Please sign in with GitHub to continue."
  end
end
```

For POST from the homepage input, store the pending question in the session before redirecting to GitHub OAuth, then replay it after sign-in.

## Files to create/modify

| Action | File |
|--------|------|
| **Gemfile** | +`sqlite-vec`, +`neighbor` |
| **database.yml** | Load vec0 extension alongside existing uuid extension |
| **Migration** | `create_content_chunks` + `create_content_embeddings` (vec0) |
| **Model** | `app/models/content_chunk.rb` (with `has_neighbors`) |
| **Concern** | `app/models/concerns/embeddable.rb` |
| **Concern** | `app/models/concerns/chat/rag_augmentable.rb` |
| **Model mods** | Include `Embeddable` in Post, Testimonial, Project |
| **Model mod** | Include `Chat::RagAugmentable` in Chat |
| **Setting** | Add `embedding_model` to `ALLOWED_KEYS` |
| **Controller** | New top-level `/chat` controller (or reuse existing with new route) |
| **Job** | `generate_embedding_job.rb` |
| **Job** | `backfill_embeddings_job.rb` (one-time for existing content) |
| **Job mod** | `chat_response_job.rb` — detect `purpose == "rag"`, call `ask_with_rag` |
| **View mod** | `home/index.html.erb` — add input + "Chat" nav link |
| **Routes** | `config/routes.rb` — add top-level `/chat` |
| **i18n** | Locale files for new strings |

## Design decisions

- **No hardcoded AI models** — everything via `Setting.get(...)`, same pattern as existing AI features
- **No new chat views** — reuse the existing beautiful templates from the remote template
- **No team slug in URLs** — multi-tenancy is internal, users see clean `/chat`
- **No chat list, no multi-chat UI** — single rotating chat keeps UX simple and costs bounded
- **No vector DB** — sqlite-vec keeps infrastructure footprint zero
- **Auth required** — connects chats to users for cost tracking via existing `Costable`

## Migration path if corpus grows

If content grows to tens of thousands of documents or semantic quality becomes insufficient:
- Switch embedding model via the setting (e.g., to `text-embedding-3-large`, 3072 dims)
- Add chunking (split long posts into overlapping windows) in `GenerateEmbeddingJob`
- Everything else (controller, concern, UI) stays the same

## Open questions for implementation

- Auto-rotation threshold: 30 messages? 24h? Both?
- Should old rotated chats be visible to admins in Madmin? (Probably yes for debugging)
- Rate limit per user: e.g., 20 messages/hour to prevent abuse even among logged-in users
- Do we index draft/unpublished content? (No — only published)
- Should failed embeddings retry or silently skip? (Retry with backoff via SolidQueue defaults)
