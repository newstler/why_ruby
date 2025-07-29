# WhyRuby.info - Ruby Advocacy Community Website

A community-driven Ruby advocacy website built with Ruby 3.4.4 and Rails 8.1 using the Solid Stack (SQLite, SolidQueue, SolidCache, SolidCable).

## Features

### Core Features
- **Universal Content Model**: Support for both articles (with markdown) and external links
- **GitHub OAuth Authentication**: Sign in with GitHub account only
- **Category System**: Dynamic categories managed through admin panel
- **Tagging System**: HABTM relationship for content tagging
- **Pinned Content**: Homepage featuring system with numbered positions
- **AI-Generated Summaries**: Automatic content summarization via OpenAI
- **Soft Deletion**: All records use archived flag instead of hard deletion

### Community Features
- **Role-Based Access**: Member and admin roles
- **Trusted User System**: Based on contribution count (3+ contents, 10+ comments)
- **Self-Regulation**: Trusted users can report inappropriate content
- **Auto-Moderation**: Content auto-hidden after 3+ reports
- **Markdown Support**: Full markdown rendering with syntax highlighting

## Setup

### Prerequisites
- Ruby 3.4.4
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

4. Set up environment variables:
```bash
cp .env.example .env
```

Edit `.env` and add your credentials:
- `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`: Get from [GitHub OAuth Apps](https://github.com/settings/developers)
- `OPENAI_API_KEY`: Get from [OpenAI](https://platform.openai.com/api-keys)

### GitHub OAuth Setup

1. Go to [GitHub Settings > Developer settings > OAuth Apps](https://github.com/settings/developers)
2. Click "New OAuth App"
3. Fill in the application details:
   - Application name: WhyRuby.info (or your preferred name)
   - Homepage URL: http://localhost:3000
   - Authorization callback URL: http://localhost:3000/users/auth/github/callback
4. Click "Register application"
5. Copy the Client ID and Client Secret to your `.env` file

## Running the Application

Start the Rails server:
```bash
rails server
```

Visit http://localhost:3000

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
- **User**: GitHub OAuth authenticated users with roles
- **Category**: Content categories with position ordering
- **Content**: Universal model for articles and links
- **Tag**: Content tags with HABTM relationship
- **Comment**: User comments on content
- **Report**: Content reports from trusted users

### Key Technologies
- **Rails 8.1**: Latest Rails with Solid Stack
- **SQLite with ULID**: Primary keys using ULID for better distribution
- **Tailwind CSS 4**: Modern utility-first CSS framework
- **Redcarpet + Rouge**: Markdown rendering with syntax highlighting
- **Avo**: Admin interface for content management
- **Kaminari**: Pagination
- **SolidQueue**: Background job processing

### Background Jobs
- `GenerateSummaryJob`: Creates AI summaries for new content
- `NotifyAdminJob`: Alerts admins when content is auto-hidden

## Development

### Running Tests
```bash
rails test
```

### Code Style
```bash
bundle exec rubocop
```

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
