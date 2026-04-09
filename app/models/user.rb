class User < ApplicationRecord
  extend FriendlyId
  friendly_id :username, use: [ :slugged, :history, :finders ]

  include Costable if defined?(Costable)
  include User::Geocodable
  include User::GithubSyncable

  # Associations
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_one :testimonial, dependent: :destroy
  has_many :published_posts, -> { published }, class_name: "Post"
  has_many :published_comments, -> { published }, class_name: "Comment"
  has_many :projects, dependent: :destroy
  has_many :visible_projects, -> { visible.by_pushed_at }, class_name: "Project"
  has_many :hidden_projects, -> { hidden.active.by_pushed_at }, class_name: "Project"
  has_many :chats, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships

  has_one_attached :avatar

  # Enums
  enum :role, { member: 0, admin: 1 }

  # Normalizations (strip whitespace from GitHub data)
  normalizes :name, :bio, :company, :location, :website, :twitter, with: ->(value) { value.strip.presence }

  # Callbacks
  before_save :precompute_bio_html, if: :will_save_change_to_bio?
  after_save :enqueue_location_normalization, if: :saved_change_to_location?
  after_save :purge_avatar, if: :remove_avatar
  after_commit :invalidate_map_cache, if: -> {
    saved_change_to_latitude? || saved_change_to_longitude? ||
    saved_change_to_public? || saved_change_to_avatar_url? ||
    saved_change_to_open_to_work?
  }

  attribute :remove_avatar, :boolean, default: false

  # Validations
  validates :github_id, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true
  validates :slug, uniqueness: true, allow_blank: true
  validates :email, uniqueness: true, allow_blank: true

  before_validation :nilify_blank_locale

  # Scopes
  scope :trusted, -> {
    where("published_posts_count >= ? AND published_comments_count >= ?", 3, 10)
  }
  scope :admins, -> { where(role: :admin) }
  scope :visible, -> { where(public: true) }
  scope :by_normalized_location, ->(loc) {
    where(normalized_location: loc).or(where(normalized_location: nil, location: loc))
  }
  scope :from_country, ->(country_code) {
    where("normalized_location LIKE ? OR normalized_location = ?", "%, #{country_code}", country_code)
  }

  # Instance methods
  def trusted?
    published_posts_count >= 3 && published_comments_count >= 10
  end

  def can_report?
    trusted?
  end

  def onboarded? = name.present?

  def effective_locale(fallback: :en)
    locale&.to_sym || fallback
  end

  def visible_ruby_repositories
    visible_projects.to_a
  end

  def hidden_ruby_repositories
    hidden_projects.to_a
  end

  def hide_repository!(repo_url)
    project = projects.find_by(github_url: repo_url)
    return unless project && !project.hidden?
    project.update!(hidden: true)
    recalculate_visible_stats!
  end

  def unhide_repository!(repo_url)
    project = projects.find_by(github_url: repo_url)
    return unless project && project.hidden?
    project.update!(hidden: false)
    recalculate_visible_stats!
  end

  def recalculate_visible_stats!
    visible = projects.visible
    gained = visible.sum { |p| p.stars_gained }
    update!(
      github_repos_count: visible.count,
      github_stars_sum: visible.sum(:stars),
      stars_gained: gained
    )
  end

  def total_github_stars
    github_stars_sum.to_i
  end

  def display_name
    name.presence || username
  end

  def country_code
    return nil if normalized_location.blank?
    normalized_location.split(", ").last
  end

  # Newsletter tracking
  def received_newsletter?(version)
    (newsletters_received || []).include?(version)
  end

  def record_newsletter_sent!(version)
    current = newsletters_received || []
    update!(newsletters_received: current + [ version ]) unless current.include?(version)
  end

  def opened_newsletter?(version)
    (newsletters_opened || []).include?(version)
  end

  def record_newsletter_opened!(version)
    current = newsletters_opened || []
    update!(newsletters_opened: current + [ version ]) unless current.include?(version)
  end

  def newsletter_open_token(version)
    Rails.application.message_verifier("newsletter_open").generate({ user_id: id, version: version })
  end

  def newsletter_unsubscribe_token
    signed_id(purpose: :newsletter_unsubscribe, expires_in: nil)
  end

  def github_profile_url
    "https://github.com/#{username}"
  end

  def github_ruby_repositories_url
    "https://github.com/#{username}?tab=repositories&q=&type=public&language=ruby&sort="
  end

  def social_links
    links = {}
    links[:website] = ensure_protocol(website) if website.present?
    links[:twitter] = "https://twitter.com/#{twitter}" if twitter.present?
    links[:linkedin] = ensure_protocol(linkedin) if linkedin.present?
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
    user.sync_github_data_from_oauth!(auth)

    user
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

  # Team membership methods
  def membership_for(team)
    memberships.find_by(team: team)
  end

  def member_of?(team)
    memberships.exists?(team: team)
  end

  def admin_of?(team)
    memberships.exists?(team: team, role: %w[admin owner])
  end

  def owner_of?(team)
    memberships.exists?(team: team, role: "owner")
  end

  # Recalculate total cost from all chats
  def recalculate_total_cost!
    update_column(:total_cost, chats.sum(:total_cost))
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
      (?:/[^\s,<>]*[^\s,.<>])?          # Optional path (allow dots mid-path, not trailing)
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

  def ensure_protocol(url)
    url.match?(%r{\A https?:// }x) ? url : "https://#{url}"
  end

  def precompute_bio_html
    self.bio_html = self.class.linkify_bio(bio)
  end

  def enqueue_location_normalization
    if location.present?
      NormalizeLocationJob.perform_later(id)
    else
      update_columns(normalized_location: nil, latitude: nil, longitude: nil)
    end
  end

  def invalidate_map_cache
    Rails.cache.delete("community_map_data")
  end

  def purge_avatar
    avatar.purge_later
  end

  def nilify_blank_locale
    self.locale = nil if locale.blank?
  end
end
