class User < ApplicationRecord
  # Soft deletion
  default_scope { where(archived: false) }
  
  # Associations
  has_many :contents, dependent: :nullify
  has_many :comments, dependent: :nullify
  has_many :reports, dependent: :nullify
  has_many :published_contents, -> { published }, class_name: "Content"
  has_many :published_comments, -> { published }, class_name: "Comment"
  
  # Enums
  enum :role, { member: 0, admin: 1 }
  
  # Validations
  validates :github_id, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
  
  # Scopes
  scope :trusted, -> { 
    where("published_contents_count >= ? AND published_comments_count >= ?", 3, 10)
  }
  scope :admins, -> { where(role: :admin) }
  
  # Devise modules (removing database_authenticatable since we're using GitHub OAuth only)
  devise :omniauthable, omniauth_providers: [:github]
  
  # Instance methods
  def trusted?
    published_contents_count >= 3 && published_comments_count >= 10
  end
  
  def can_report?
    trusted?
  end
  
  # Class methods for Omniauth
  def self.from_omniauth(auth)
    where(github_id: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.username = auth.info.nickname
      user.avatar_url = auth.info.image
    end
  end
  
  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.github_data"] && session["devise.github_data"]["extra"]["raw_info"]
        user.email = data["email"] if user.email.blank?
      end
    end
  end
end
