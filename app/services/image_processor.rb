# Service for processing uploaded images into multiple WebP variants
# Uses ImageMagick directly for compatibility with server constraints
class ImageProcessor
  ALLOWED_CONTENT_TYPES = %w[image/jpeg image/jpg image/png image/webp].freeze

  # Variant dimensions (width x height)
  VARIANTS = {
    blur: { width: 20, height: 20, quality: 60 },      # For placeholder
    thumb: { width: 684, height: 384, quality: 92 },   # For tiles (2x for retina)
    medium: { width: 1664, height: 936, quality: 94 }, # For post pages (2x for retina)
    large: { width: 1920, height: 1080, quality: 95 }  # Capped "original"
  }.freeze

  def initialize(blob_or_attachment)
    @blob = blob_or_attachment.is_a?(ActiveStorage::Blob) ? blob_or_attachment : blob_or_attachment.blob
  end

  def process!
    return { error: "File too large (max #{Post::MAX_IMAGE_SIZE / 1.megabyte}MB)" } if @blob.byte_size > Post::MAX_IMAGE_SIZE
    return { error: "Invalid file type" } unless ALLOWED_CONTENT_TYPES.include?(@blob.content_type)

    variants = {}
    blur_data = nil

    @blob.open do |tempfile|
      # Generate blur placeholder as base64
      blur_data = generate_blur_placeholder(tempfile.path)

      # Generate each variant
      VARIANTS.each do |name, config|
        next if name == :blur # Already handled above

        variant_blob = generate_variant(tempfile.path, config)
        variants[name] = variant_blob.id if variant_blob
      end
    end

    {
      success: true,
      blur_data: blur_data,
      variants: variants
    }
  rescue => e
    Rails.logger.error "ImageProcessor error: #{e.message}"
    { error: "Processing failed: #{e.message}" }
  end

  # Process an image from a URL (for metadata fetching)
  def self.process_from_url(url, post)
    return unless url.present?

    require "open-uri"

    begin
      image_io = URI.open(url,
        "User-Agent" => "Ruby/#{RUBY_VERSION}",
        read_timeout: 10,
        open_timeout: 10
      )

      # Check file size before processing
      if image_io.size > Post::MAX_IMAGE_SIZE
        Rails.logger.warn "Image from URL too large: #{image_io.size} bytes (max #{Post::MAX_IMAGE_SIZE} bytes)"
        return nil
      end

      # Create a temporary file for processing
      temp_file = Tempfile.new([ "remote_image", File.extname(URI.parse(url).path) ])
      temp_file.binmode
      temp_file.write(image_io.read)
      temp_file.rewind

      # Process the image
      process_and_attach_image(temp_file, post, File.basename(URI.parse(url).path))

    rescue => e
      Rails.logger.error "Failed to fetch/process image from URL #{url}: #{e.message}"
      nil
    ensure
      temp_file&.close
      temp_file&.unlink
    end
  end

  private

  def generate_blur_placeholder(source_path)
    blur_file = Tempfile.new([ "blur", ".webp" ])

    begin
      # Generate tiny WebP for blur effect
      cmd = [
        "convert",
        source_path,
        "-resize", "20x20^",           # Fill 20x20 area
        "-gravity", "center",
        "-extent", "20x20",            # Crop to exact 20x20
        "-quality", "60",
        "-gaussian-blur", "0x8",       # Add blur for better placeholder
        "-define", "webp:method=6",    # Max compression
        "webp:#{blur_file.path}"
      ]

      unless system(*cmd, err: File::NULL)
        Rails.logger.error "Failed to generate blur placeholder"
        return nil
      end

      # Convert to base64
      "data:image/webp;base64,#{Base64.strict_encode64(File.read(blur_file.path))}"

    ensure
      blur_file.close
      blur_file.unlink
    end
  end

  def generate_variant(source_path, config)
    variant_file = Tempfile.new([ "variant", ".webp" ])

    begin
      # Resize and convert to WebP with high quality
      cmd = [
        "convert",
        source_path,
        "-resize", "#{config[:width]}x#{config[:height]}>",  # Only shrink larger images
        "-filter", "Lanczos",                                # Best quality resize filter
        "-quality", config[:quality].to_s,
        "-define", "webp:lossless=false",                    # Use lossy for smaller size
        "-define", "webp:method=6",                          # Best quality (slower)
        "-define", "webp:alpha-quality=100",                 # Preserve alpha quality
        "-define", "webp:image-hint=photo",                  # Optimize for photos
        "-strip",                                             # Remove metadata
        "webp:#{variant_file.path}"
      ]

      unless system(*cmd, err: File::NULL)
        Rails.logger.error "Failed to generate variant: #{config.inspect}"
        return nil
      end

      # Create a new blob for this variant
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

  def self.process_and_attach_image(file, post, filename = "image")
    # Keep original filename for now, will be converted to WebP during processing

    # First attach the original
    post.featured_image.attach(
      io: file,
      filename: filename
    )

    # Process variants
    processor = new(post.featured_image)
    result = processor.process!

    if result[:success]
      post.update_columns(
        image_blur_data: result[:blur_data],
        image_variants: result[:variants]
      )
    end

    result
  end
end
