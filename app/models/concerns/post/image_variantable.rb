# app/models/concerns/post/image_variantable.rb
module Post::ImageVariantable
  extend ActiveSupport::Concern

  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg image/jpg image/png image/webp image/tiff image/x-tiff
  ].freeze

  IMAGE_VARIANTS = {
    tile: { width: 684, height: 384, quality: 92 },
    post: { width: 1664, height: 936, quality: 94 },
    og: { width: 1200, height: 630, quality: 95 }
  }.freeze

  MAX_IMAGE_SIZE = 20.megabytes

  # Generate all WebP variants from featured_image
  def process_image_variants!
    return { error: "No image attached" } unless featured_image.attached?
    return { error: "File too large" } if featured_image.blob.byte_size > MAX_IMAGE_SIZE
    return { error: "Invalid file type" } unless ALLOWED_CONTENT_TYPES.include?(featured_image.blob.content_type)

    variants = {}

    featured_image.blob.open do |tempfile|
      IMAGE_VARIANTS.each do |name, config|
        variant_blob = generate_image_variant(tempfile.path, config)
        variants[name] = variant_blob.id if variant_blob
      end
    end

    update_columns(image_variants: variants)
    { success: true, variants: variants }
  rescue => e
    Rails.logger.error "Image processing error: #{e.message}"
    { error: "Processing failed: #{e.message}" }
  end

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

    process_image_variants!
  end

  def clear_image_variants!
    if image_variants.present?
      image_variants.each do |_size, blob_id|
        ActiveStorage::Blob.find_by(id: blob_id)&.purge_later
      end
    end

    update_columns(image_variants: nil)
  end

  # Attach image from URL and process variants
  def attach_image_from_url!(image_url)
    return if image_url.blank?

    require "open-uri"

    image_io = URI.open(image_url,
      "User-Agent" => "Ruby/#{RUBY_VERSION}",
      read_timeout: 10,
      open_timeout: 10
    )

    return if image_io.size > MAX_IMAGE_SIZE

    temp_file = Tempfile.new([ "remote_image", File.extname(URI.parse(image_url).path) ])
    temp_file.binmode
    temp_file.write(image_io.read)
    temp_file.rewind

    featured_image.attach(io: temp_file, filename: File.basename(URI.parse(image_url).path))
    process_image_variants!
  rescue => e
    Rails.logger.error "Failed to fetch/process image from URL #{image_url}: #{e.message}"
  ensure
    temp_file&.close
    temp_file&.unlink
  end

  private

  def generate_image_variant(source_path, config)
    variant_file = Tempfile.new([ "variant", ".webp" ])

    begin
      cmd = [
        "convert", source_path,
        "-resize", "#{config[:width]}x#{config[:height]}>",
        "-filter", "Lanczos",
        "-quality", config[:quality].to_s,
        "-define", "webp:lossless=false",
        "-define", "webp:method=6",
        "-define", "webp:alpha-quality=100",
        "-define", "webp:image-hint=photo",
        "-strip",
        "webp:#{variant_file.path}"
      ]

      unless system(*cmd, err: File::NULL)
        Rails.logger.error "Failed to generate variant: #{config.inspect}"
        return nil
      end

      ActiveStorage::Blob.create_and_upload!(
        io: File.open(variant_file.path),
        filename: "variant_#{config[:width]}x#{config[:height]}.webp",
        content_type: "image/webp"
      )
    ensure
      variant_file.close
      variant_file.unlink
    end
  end

  def process_featured_image_if_needed
    return unless featured_image.attached?

    should_process = !has_processed_images? ||
                    (previous_changes.key?("updated_at") && featured_image.blob.created_at > 1.minute.ago)

    return unless should_process

    Rails.logger.info "Processing image for Post ##{id}"
    result = process_image_variants!

    if result[:success]
      Rails.logger.info "Successfully processed image for Post ##{id}"
    else
      Rails.logger.error "Failed to process image for Post ##{id}: #{result[:error]}"
    end
  end

  def featured_image_validation
    return unless featured_image.attached?

    if featured_image.blob.byte_size > MAX_IMAGE_SIZE
      errors.add(:featured_image, "is too large (maximum is #{MAX_IMAGE_SIZE / 1.megabyte}MB)")
    end

    unless ALLOWED_CONTENT_TYPES.include?(featured_image.blob.content_type)
      errors.add(:featured_image, "must be a JPEG, PNG, WebP, or TIFF image")
    end
  end
end
