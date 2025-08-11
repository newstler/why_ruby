class Post < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: [ :slugged, :history, :finders ]

  # Virtual attributes
  attr_accessor :duplicate_post

  # Constants
  POST_TYPES = %w[article link success_story].freeze

  # Associations
  belongs_to :user
  belongs_to :category, -> { unscoped }, optional: true
  has_and_belongs_to_many :tags
  has_many :comments, dependent: :destroy
  has_many :reports, dependent: :destroy

  # Validations
  validates :title, presence: true
  validates :slug, uniqueness: true, allow_blank: true
  validates :post_type, inclusion: { in: POST_TYPES }
  validate :content_or_url_or_logo_present
  validate :url_uniqueness
  validates :url, format: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true
  validates :pin_position, uniqueness: true, allow_nil: true, numericality: { only_integer: true }
  validates :category_id, presence: true, unless: :success_story?
  validate :logo_svg_valid_if_present

  # Default scope
  default_scope { order(created_at: :desc) }

  # Scopes
  scope :published, -> { where(published: true) }
  scope :pinned, -> { where.not(pin_position: nil) }
  scope :articles, -> { where(post_type: "article") }
  scope :links, -> { where(post_type: "link") }
  scope :success_stories, -> { where(post_type: "success_story") }
  scope :homepage_order, -> { reorder(:pin_position, created_at: :desc) }
  scope :needing_review, -> { where(needs_admin_review: true) }

  # Callbacks
  before_validation :normalize_url
  before_validation :set_post_type
  before_validation :clean_category_for_success_stories
  before_validation :clean_logo_svg
  after_create :generate_summary_job
  after_update :regenerate_summary_if_needed
  after_save :generate_png_for_success_story, if: -> { success_story? && saved_change_to_logo_svg? }
  after_update :check_reports_threshold
  after_create :update_user_counter_caches
  after_update :update_user_counter_caches
  after_destroy :update_user_counter_caches

  # Instance methods
  def article?
    post_type == "article"
  end

  def link?
    post_type == "link"
  end

  def success_story?
    post_type == "success_story"
  end

  def should_generate_new_friendly_id?
    title_changed? || super
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

  def auto_hide_if_needed!
    if reports_count >= 3
      update!(needs_admin_review: true, published: false)
      NotifyAdminJob.perform_later(self)
    end
  end



  private

  def generate_png_for_success_story
    SuccessStoryImageGenerator.new(self).generate!
  end

  def content_or_url_or_logo_present
    if success_story?
      if logo_svg.blank?
        errors.add(:logo_svg, "is required for success stories")
      end
      if content.blank?
        errors.add(:content, "is required for success stories")
      end
      if url.present?
        errors.add(:url, "must be blank for success stories")
      end
    elsif article?
      if content.blank?
        errors.add(:content, "is required for articles")
      end
      if url.present?
        errors.add(:url, "must be blank for articles")
      end
    elsif link?
      if url.blank?
        errors.add(:url, "is required for external links")
      end
      if content.present?
        errors.add(:content, "must be blank for external links")
      end
    end
  end

  def logo_svg_valid_if_present
    return unless logo_svg.present?

    unless logo_svg.include?("<svg") && logo_svg.include?("</svg>")
      errors.add(:logo_svg, "must be valid SVG content")
    end
  end

  def set_post_type
    # Only set post_type if it's blank (for backward compatibility)
    if post_type.blank?
      self.post_type = if logo_svg.present?
                         "success_story"
      elsif url.present?
                         "link"
      else
                         "article"
      end
    end
  end

  def clean_category_for_success_stories
    # Convert empty string category_id to nil for success stories
    if post_type == "success_story" && category_id == ""
      self.category_id = nil
    end
  end

  def clean_logo_svg
    return unless logo_svg.present?

    # Sanitize the SVG content to prevent XSS attacks
    self.logo_svg = SvgSanitizer.sanitize(logo_svg)
  end

  def generate_summary_job
    # Only generate summary if published and summary is blank
    GenerateSummaryJob.perform_later(self) if published? && summary.blank?
  end

  def regenerate_summary_if_needed
    # Only regenerate summary if content/title/url changed and summary wasn't manually changed
    # This prevents overwriting manually edited summaries
    if published? &&
       (saved_change_to_content? || saved_change_to_title? || saved_change_to_url?) &&
       !saved_change_to_summary?
      GenerateSummaryJob.perform_later(self, force: true)
    end
  end

  def check_reports_threshold
    auto_hide_if_needed! if saved_change_to_reports_count?
  end

  def update_user_counter_caches
    # Update the counter if:
    # 1. A new published post was created
    # 2. The published status changed
    # 3. A post was destroyed
    if destroyed? || (persisted? && (saved_change_to_published? || (published? && previously_new_record?)))
      count = user.posts.published.count
      user.update_column(:published_posts_count, count) if user.present?
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
    self.url = url.strip.gsub(/\/+$/, "")

    # Normalize common URL variations
    # Convert http to https for common domains that support it
    if url.match?(/^http:\/\/(www\.)?(github\.com|twitter\.com|youtube\.com|linkedin\.com|stackoverflow\.com)/i)
      self.url = url.sub(/^http:/, "https:")
    end
  end
end
