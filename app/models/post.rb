class Post < ApplicationRecord
  # Soft deletion
  default_scope { where(archived: false) }
  
  # Virtual attributes
  attr_accessor :duplicate_post
  
  # Associations
  belongs_to :user
  belongs_to :category, -> { unscoped }
  has_and_belongs_to_many :tags
  has_many :comments, dependent: :destroy
  has_many :reports, dependent: :destroy
  
  # Validations
  validates :title, presence: true
  validate :content_or_url_present
  validate :url_uniqueness
  validates :url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
  validates :pin_position, uniqueness: true, allow_nil: true, numericality: { only_integer: true }
  
  # Scopes
  scope :published, -> { where(published: true, archived: false) }
  scope :pinned, -> { where.not(pin_position: nil) }
  scope :articles, -> { where(url: [nil, ""]) }
  scope :links, -> { where.not(url: [nil, ""]) }
  scope :homepage_order, -> { order(:pin_position, created_at: :desc) }
  scope :needing_review, -> { where(needs_admin_review: true) }
  
  # Callbacks
  before_validation :normalize_url
  after_create :generate_summary_job
  after_update :regenerate_summary_if_needed
  after_update :check_reports_threshold
  after_save :update_user_counter_caches
  after_destroy :update_user_counter_caches
  
  # Instance methods
  def article?
    url.blank?
  end
  
  def link?
    url.present?
  end
  
  def auto_hide_if_needed!
    if reports_count >= 3
      update!(needs_admin_review: true, published: false)
      NotifyAdminJob.perform_later(self)
    end
  end
  
  private
  
  def content_or_url_present
    if content.blank? && url.blank?
      errors.add(:base, "Either content or URL must be present")
    elsif content.present? && url.present?
      errors.add(:base, "Cannot have both content and URL")
    end
  end
  
  def generate_summary_job
    GenerateSummaryJob.perform_later(self) if published?
  end
  
  def regenerate_summary_if_needed
    # Regenerate summary if content or title changed and post is published
    if published? && (saved_change_to_content? || saved_change_to_title? || saved_change_to_url?)
      # Clear existing summary to force regeneration
      update_column(:summary, nil)
      GenerateSummaryJob.perform_later(self)
    end
  end
  
  def check_reports_threshold
    auto_hide_if_needed! if saved_change_to_reports_count?
  end
  
  def update_user_counter_caches
    if saved_change_to_published? || saved_change_to_archived?
      count = user.posts.published.count
      user.update_column(:published_posts_count, count)
    end
  end
  
  def url_uniqueness
    return unless url.present?
    
    existing_post = Post.where(url: url).where.not(id: id).first
    if existing_post
      self.duplicate_post = existing_post
      errors.add(:url, "has already been posted")
    end
  end
  
  def normalize_url
    return unless url.present?
    
    # Remove trailing slashes
    self.url = url.strip.gsub(/\/+$/, '')
    
    # Normalize common URL variations
    # Convert http to https for common domains that support it
    if url.match?(/^http:\/\/(www\.)?(github\.com|twitter\.com|youtube\.com|linkedin\.com|stackoverflow\.com)/i)
      self.url = url.sub(/^http:/, 'https:')
    end
  end
end 