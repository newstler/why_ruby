class Post < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: [ :slugged, :history, :finders ]

  # Virtual attributes
  attr_accessor :duplicate_post

  # Constants
  POST_TYPES = %w[article link success_story].freeze
  MAX_IMAGE_SIZE = 20.megabytes # 20MB limit for uploaded images

  # Associations
  belongs_to :user
  belongs_to :category, -> { unscoped }, optional: true
  has_and_belongs_to_many :tags
  has_many :comments, dependent: :destroy
  has_many :reports, dependent: :destroy

  # ActiveStorage attachments
  has_one_attached :featured_image  # For all posts (articles, links, and success stories)

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
  validate :featured_image_validation

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
  after_save :generate_success_story_image, if: -> { success_story? && saved_change_to_logo_svg? }
  after_commit :process_featured_image_if_needed
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

  def generate_success_story_image
    # Force regeneration when logo changes on an existing record
    # saved_change_to_logo_svg? returns true if logo_svg changed in the last save
    # For new records, we don't need to force (no existing image)
    # For existing records with logo changes, we need to force regeneration
    force_regenerate = saved_change_to_logo_svg? && !saved_change_to_id?

    Rails.logger.info "GenerateSuccessStoryImageJob triggered for post #{id}: force=#{force_regenerate}, logo_changed=#{saved_change_to_logo_svg?}, new_record=#{saved_change_to_id?}"

    GenerateSuccessStoryImageJob.perform_later(self, force: force_regenerate)
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
    # Generate summary if summary is blank - for all post types, published or not
    GenerateSummaryJob.perform_later(self) if summary.blank?
  end

  def regenerate_summary_if_needed
    # Only regenerate summary if content/title/url changed and summary wasn't manually changed
    # This prevents overwriting manually edited summaries
    if (saved_change_to_content? || saved_change_to_title? || saved_change_to_url?) &&
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

  def featured_image_validation
    return unless featured_image.attached?

    # Check file size
    if featured_image.blob.byte_size > MAX_IMAGE_SIZE
      errors.add(:featured_image, "is too large (maximum is #{MAX_IMAGE_SIZE / 1.megabyte}MB)")
    end

    # Check allowed content types (no GIFs)
    allowed_types = %w[image/jpeg image/jpg image/png image/webp]
    unless allowed_types.include?(featured_image.blob.content_type)
      errors.add(:featured_image, "must be a JPEG, PNG, or WebP image (GIFs not allowed)")
    end
  end

  def process_featured_image_if_needed
    # Check if we have a new image attachment that needs processing
    return unless featured_image.attached?

    # Process if:
    # 1. No variants exist yet (new upload or migration)
    # 2. Featured image was just attached/changed
    should_process = !has_processed_images? ||
                    (previous_changes.key?("updated_at") && featured_image.blob.created_at > 1.minute.ago)

    return unless should_process

    Rails.logger.info "Processing image for Post ##{id}"
    processor = ImageProcessor.new(featured_image)
    result = processor.process!

    if result[:success]
      update_columns(
        image_variants: result[:variants]
      )
      Rails.logger.info "Successfully processed image for Post ##{id}"
    else
      Rails.logger.error "Failed to process image for Post ##{id}: #{result[:error]}"
    end
  end

  public

  # Image variant methods (public so they can be used in views/helpers)
  def image_variant(size = :medium)
    return nil unless featured_image.attached? && image_variants.present?

    variant_id = image_variants[size.to_s]
    return featured_image.blob unless variant_id

    ActiveStorage::Blob.find_by(id: variant_id) || featured_image.blob
  end

  def image_url_for_size(size = :medium)
    blob = image_variant(size)
    return nil unless blob

    Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
  end

  def has_processed_images?
    image_variants.present?
  end

  def reprocess_image!
    return unless featured_image.attached?

    processor = ImageProcessor.new(featured_image)
    result = processor.process!

    if result[:success]
      update_columns(
        image_variants: result[:variants]
      )
    end

    result
  end

  def clear_image_variants!
    # Clear variant blobs if they exist
    if image_variants.present?
      image_variants.each do |_size, blob_id|
        ActiveStorage::Blob.find_by(id: blob_id)&.purge_later
      end
    end

    # Clear image processing fields
    update_columns(image_variants: nil)
  end
end
