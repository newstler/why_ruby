class User < ApplicationRecord
  extend FriendlyId
  friendly_id :username, use: [ :slugged, :history, :finders ]

  # Associations
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_one :testimonial, dependent: :destroy
  has_many :published_posts, -> { published }, class_name: "Post"
  has_many :published_comments, -> { published }, class_name: "Comment"

  # Enums
  enum :role, { member: 0, admin: 1 }

  # Normalizations (strip whitespace from GitHub data)
  normalizes :name, :bio, :company, :location, :website, :twitter, with: ->(value) { value.strip.presence }

  # Callbacks
  before_save :precompute_bio_html, if: :will_save_change_to_bio?

  # Validations
  validates :github_id, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true
  validates :slug, uniqueness: true, allow_blank: true
  validates :email, presence: true, uniqueness: true

  # Scopes
  scope :trusted, -> {
    where("published_posts_count >= ? AND published_comments_count >= ?", 3, 10)
  }
  scope :admins, -> { where(role: :admin) }
  scope :visible, -> { where(public: true) }

  # Devise modules for GitHub OAuth
  devise :omniauthable, omniauth_providers: [ :github ]

  # Instance methods
  def trusted?
    published_posts_count >= 3 && published_comments_count >= 10
  end

  def can_report?
    trusted?
  end

  def ruby_repositories
    return [] unless github_repos.present?

    repos = JSON.parse(github_repos, symbolize_names: true)

    # Repositories are already filtered for Ruby language and exclude forks
    # during the fetch process in GithubDataFetcher
    # Just sort by pushed_at descending (most recently pushed first)
    repos.sort_by { |repo| repo[:pushed_at].present? ? -Time.parse(repo[:pushed_at]).to_i : 0 }
  rescue JSON::ParserError, ArgumentError => e
    Rails.logger.error "Error parsing repositories: #{e.message}"
    []
  end

  # Get visible repositories (excludes hidden)
  def visible_ruby_repositories
    return ruby_repositories if hidden_repo_urls.empty?
    ruby_repositories.reject { |repo| hidden_repo_urls.include?(repo[:url]) }
  end

  # Get hidden repositories only
  def hidden_ruby_repositories
    return [] if hidden_repo_urls.empty?
    ruby_repositories.select { |repo| hidden_repo_urls.include?(repo[:url]) }
  end

  # Parse hidden repos JSON (memoized for performance)
  def hidden_repo_urls
    @hidden_repo_urls ||= begin
      return [] if hidden_repos.blank?
      JSON.parse(hidden_repos)
    rescue JSON::ParserError
      []
    end
  end

  # Clear memoization when hidden_repos changes
  def hidden_repos=(value)
    @hidden_repo_urls = nil
    write_attribute(:hidden_repos, value)
  end

  # Add repo to hidden list
  def hide_repository!(repo_url)
    return if hidden_repo_urls.include?(repo_url)
    update!(hidden_repos: (hidden_repo_urls + [ repo_url ]).to_json)
    recalculate_visible_stats!
  end

  # Remove repo from hidden list (unhide)
  def unhide_repository!(repo_url)
    return unless hidden_repo_urls.include?(repo_url)
    new_urls = hidden_repo_urls - [ repo_url ]
    update!(hidden_repos: new_urls.empty? ? nil : new_urls.to_json)
    recalculate_visible_stats!
  end

  # Recalculate stats based on visible repos only
  def recalculate_visible_stats!
    repos = visible_ruby_repositories
    update!(
      github_repos_count: repos.size,
      github_stars_sum: repos.sum { |r| r[:stars].to_i }
    )
  end

  def total_github_stars
    return github_stars_sum if respond_to?(:github_stars_sum) && github_stars_sum.present?

    repos = ruby_repositories
    return 0 if repos.blank?

    repos.sum { |repo| repo[:stars].to_i }
  rescue => _e
    0
  end

  def display_name
    name.presence || username
  end

  # Newsletter tracking
  def received_newsletter?(version)
    (newsletters_received || []).include?(version)
  end

  def record_newsletter_sent!(version)
    current = newsletters_received || []
    update!(newsletters_received: current + [ version ]) unless current.include?(version)
  end

  def github_profile_url
    "https://github.com/#{username}"
  end

  def github_ruby_repositories_url
    "https://github.com/#{username}?tab=repositories&q=&type=public&language=ruby&sort="
  end

  def social_links
    links = {}
    links[:website] = website if website.present?
    links[:twitter] = "https://twitter.com/#{twitter}" if twitter.present?
    links[:linkedin] = linkedin if linkedin.present?
    links[:github] = github_profile_url
    links
  end

  def should_generate_new_friendly_id?
    username_changed? || super
  end

  # Ensure old slug is saved to history when slug changes
  before_save :create_slug_history, if: :will_save_change_to_slug?

  def create_slug_history
    if slug_was.present? && slug_was != slug
      FriendlyId::Slug.create!(
        slug: slug_was,
        sluggable_id: id,
        sluggable_type: self.class.name
      ) rescue nil
    end
  end

  # Class methods for Omniauth
  def self.from_omniauth(auth)
    user = where(github_id: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.username = auth.info.nickname
      user.avatar_url = auth.info.image
    end

    # Fetch and update GitHub data on every sign in
    GithubDataFetcher.new(user, auth).fetch_and_update!

    user
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.github_data"] && session["devise.github_data"]["extra"]["raw_info"]
        user.email = data["email"] if user.email.blank?
      end
    end
  end

  # Cross-domain session sync methods
  def generate_cross_domain_token!
    token = SecureRandom.urlsafe_base64(32)
    update_columns(
      cross_domain_token: token,
      cross_domain_token_expires_at: 30.seconds.from_now
    )
    token
  end

  def self.authenticate_cross_domain_token(token)
    return nil if token.blank?

    user = find_by(cross_domain_token: token)
    return nil unless user
    return nil if user.cross_domain_token_expires_at < Time.current

    # Invalidate token (one-time use)
    user.update_columns(cross_domain_token: nil, cross_domain_token_expires_at: nil)
    user
  end

  # Linkify URLs and GitHub @mentions in bio text
  # Returns precomputed HTML for display
  def self.linkify_bio(text)
    return "" if text.blank?

    # Escape HTML to prevent XSS
    escaped = ERB::Util.html_escape(text)

    # Pattern for GitHub @mentions
    github_pattern = /(?<=\s|^)@([a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?)/

    # Pattern for URLs (with or without protocol)
    url_pattern = %r{
      (?:https?://)?                    # Optional protocol
      (?:www\.)?                        # Optional www
      [a-zA-Z0-9][a-zA-Z0-9\-]*         # Domain name
      \.[a-zA-Z]{2,}                    # TLD
      (?:/[^\s,.<>]*)?                  # Optional path
    }x

    # Replace GitHub @mentions first
    result = escaped.gsub(github_pattern) do |match|
      username = Regexp.last_match(1)
      %(<a href="https://github.com/#{username}" target="_blank" rel="noopener" class="underline hover:text-red-600 transition-colors">#{match}</a>)
    end

    # Replace URLs (skip github.com since @mentions already handled)
    result.gsub(url_pattern) do |match|
      next match if match.include?("github.com")
      url = match.start_with?("http") ? match : "https://#{match}"
      %(<a href="#{url}" target="_blank" rel="noopener" class="underline hover:text-red-600 transition-colors">#{match}</a>)
    end
  end

  private

  def precompute_bio_html
    self.bio_html = self.class.linkify_bio(bio)
  end
end
