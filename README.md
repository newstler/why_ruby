# WhyRuby.info & RubyCommunity.org

Ruby advocacy site and developer community. Built with Ruby 4.0.1 and Rails 8.2 on the Solid Stack (SQLite, SolidQueue, SolidCache, SolidCable).

## Features

### Content
- **Universal Content Model**: Articles (markdown), external links, and success stories
- **AI-Generated Summaries**: Automatic content summarization via OpenAI/Anthropic
- **Category & Tagging System**: Dynamic categories and HABTM tags
- **Markdown Support**: Full markdown rendering with syntax highlighting (Redcarpet + Rouge)

### Community (rubycommunity.org)
- **Developer Profiles**: GitHub-synced profiles with bio, company, location, repositories
- **Interactive Map**: Geocoded developer locations on a Leaflet.js world map
- **Project Rankings**: GitHub repos with daily star trends and sorting (trending, top, new)
- **Testimonials**: Users write why they love Ruby; AI generates headline/quote for the home page carousel
- **Profile Settings**: Hide repositories, "Open to Work" badge, newsletter preferences

### Multi-Domain
- **whyruby.info**: Advocacy content, articles, success stories, testimonials
- **rubycommunity.org**: Community profiles, map, project rankings
- **Cross-domain auth**: OAuth via primary domain with single-use token session sync

### Newsletter
- **Timezone-aware delivery**: Sends at 10:10 AM local time per user
- **Open tracking**: Pixel-based open tracking per version
- **Unsubscribe**: One-click unsubscribe via token URL

### Moderation
- **Role-Based Access**: Member and admin roles
- **Trusted User System**: Based on contribution count (3+ posts, 10+ comments)
- **Self-Regulation**: Trusted users can report inappropriate content
- **Auto-Moderation**: Content auto-hidden after 3+ reports

## Setup

### Prerequisites
- Ruby 4.0.1
- SQLite 3
- Node.js (for JavaScript runtime)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd why_ruby
```

2. Install dependencies:
```bash
bundle install
```

3. Create and setup the database:
```bash
rails db:create
rails db:migrate
rails db:seed
```

4. Set up Rails credentials for development:
```bash
rails credentials:edit --environment development
```

Add your credentials:
```yaml
github:
  client_id: your_github_client_id
  client_secret: your_github_client_secret

openai:
  api_key: your_openai_api_key  # Optional
```

Get credentials from:
- GitHub OAuth: [GitHub OAuth Apps](https://github.com/settings/developers)
- OpenAI API: [OpenAI](https://platform.openai.com/api-keys)

### GitHub OAuth Setup

1. Go to [GitHub Settings > Developer settings > OAuth Apps](https://github.com/settings/developers)
2. Click "New OAuth App"
3. Fill in the application details:
   - Application name: WhyRuby.info (or your preferred name)
   - Homepage URL: http://localhost:3000
   - Authorization callback URL: http://localhost:3000/users/auth/github/callback
4. Click "Register application"
5. Copy the Client ID and Client Secret to your Rails credentials

## Running the Application

Start the development server (runs Rails + Tailwind CSS watcher):
```bash
bin/dev
```

Visit http://localhost:3003

**Important**: Always use `bin/dev` instead of `rails server`.

## Admin Access

The seed data creates a test admin user. In production, you'll need to:
1. Sign in with GitHub
2. Use rails console to promote your user to admin:
```bash
rails runner "User.find_by(username: 'your-github-username').update!(role: :admin)"
```

Access the admin panel at `/admin`

## Architecture

### Models
- **User**: GitHub OAuth authenticated users with roles, geocoded location, timezone, profile settings
- **Post**: Universal content model for articles, links, and success stories
- **Category**: Content categories with position ordering
- **Tag**: Content tags with HABTM relationship
- **Comment**: User comments on content
- **Report**: Content reports from trusted users
- **Testimonial**: User testimonials with AI-generated fields
- **Project**: GitHub repositories with star counts and language
- **StarSnapshot**: Daily star count snapshots for trend tracking

### Key Technologies
- **Ruby 4.0.1 / Rails 8.2**: Latest Rails with Solid Stack
- **SQLite with UUIDv7**: String primary keys for time-ordered uniqueness
- **Tailwind CSS 4**: Utility-first CSS via `tailwindcss-rails`
- **Hotwire (Turbo + Stimulus)**: Frontend interactivity, infinite scroll, interactive map
- **Avo**: Admin interface for content management
- **Kaminari**: Pagination
- **SolidQueue**: Background job processing
- **Leaflet.js**: Interactive community map
- **Brakeman**: Security scanning (runs on every commit via lefthook)

### Background Jobs
- `GenerateSummaryJob`: Creates AI summaries for new content
- `GenerateTestimonialFieldsJob`: AI-generates headline, subheadline, and quote from testimonials
- `ValidateTestimonialJob`: LLM-validates testimonial content
- `UpdateGithubDataJob`: Refreshes user GitHub data via GraphQL API
- `NormalizeLocationJob`: Geocodes user locations for the community map
- `ScheduledNewsletterJob`: Timezone-aware newsletter delivery
- `NotifyAdminJob`: Alerts admins when content is auto-hidden

## Development

### Running Tests
```bash
rails test
```

### Code Style & Security
```bash
bundle exec rubocop        # Lint
bin/brakeman --no-pager     # Security scan
```

Both run automatically on every commit via lefthook.

### Database Console
```bash
rails db
```

## Deployment

This application is configured for deployment with Kamal. See `config/deploy.yml` for configuration.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is open source and available under the MIT License.
