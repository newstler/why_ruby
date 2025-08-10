class User < ApplicationRecord
  extend FriendlyId
  friendly_id :username, use: [:slugged, :history, :finders]
  
  # Associations
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :published_posts, -> { published }, class_name: "Post"
  has_many :published_comments, -> { published }, class_name: "Comment"
  
  # Enums
  enum :role, { member: 0, admin: 1 }
  
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
  
  # Devise modules for GitHub OAuth
  devise :omniauthable, omniauth_providers: [:github]
  
  # Instance methods
  def trusted?
    published_posts_count >= 3 && published_comments_count >= 10
  end
  
  def can_report?
    trusted?
  end
  
  def ruby_repositories
    return [] unless github_repos.present?
    JSON.parse(github_repos, symbolize_names: true)
  rescue JSON::ParserError
    []
  end
  
  def display_name
    name.presence || username
  end
  
  def github_profile_url
    "https://github.com/#{username}"
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
end
