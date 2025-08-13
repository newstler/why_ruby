class SuccessStoryImageGenerator
  # Template should be 1200x630 WebP format
  TEMPLATE_PATH = Rails.root.join("app", "assets", "images", "success_story_template.webp")
  FALLBACK_PNG_TEMPLATE = Rails.root.join("app", "assets", "images", "success_story_template.png")

  # OG Image dimensions
  OG_WIDTH = 1200
  OG_HEIGHT = 630

  # Logo positioning (centered in the template)
  LOGO_MAX_WIDTH = 410   # Maximum width for logo
  LOGO_MAX_HEIGHT = 190  # Maximum height for logo
  LOGO_CENTER_X = 410    # Center X position (1200/2)
  LOGO_CENTER_Y = 145    # Center Y position (630/2)

  # NOTE: This service uses ImageMagick's 'convert' command directly for v6 compatibility
  # No Ruby gems required, just ImageMagick binary installed on the system

  def initialize(post)
    @post = post
  end

  def generate!
    return unless @post.success_story? && @post.logo_svg.present?

    # Check if ImageMagick is available
    unless system("which convert > /dev/null 2>&1")
      Rails.logger.error "ImageMagick 'convert' command not found"
      return nil
    end

    # Convert SVG logo to WebP and overlay on template
    webp_data = generate_social_image

    # Store the generated WebP in ActiveStorage
    if webp_data && !webp_data.empty?
      @post.featured_image.attach(
        io: StringIO.new(webp_data),
        filename: "#{@post.slug}-social.webp",
        content_type: "image/webp"
      )

      # Also process variants for the success story image
      if @post.featured_image.attached?
        processor = ImageProcessor.new(@post.featured_image)
        result = processor.process!

        if result[:success]
          @post.update_columns(
            image_blur_data: result[:blur_data],
            image_variants: result[:variants]
          )
        end
      end
    end
  end

  private

  def generate_social_image
    # Create temp files
    svg_file = Tempfile.new([ "logo", ".svg" ])
    logo_file = Tempfile.new([ "logo_converted", ".webp" ])
    output_file = Tempfile.new([ "success_story", ".webp" ])

    begin
      # Write SVG to file
      svg_file.write(@post.logo_svg)
      svg_file.rewind

      # Determine which template to use
      template_path = File.exist?(TEMPLATE_PATH) ? TEMPLATE_PATH : FALLBACK_PNG_TEMPLATE
      unless File.exist?(template_path)
        Rails.logger.error "No template file found for success story image generation"
        return nil
      end

      # Dual approach: Try rsvg-convert first (better SVG handling), fall back to ImageMagick
      converted = false

      # Method 1: Try rsvg-convert (preferred - no black border issues)
      if system("which", "rsvg-convert", out: File::NULL, err: File::NULL)
        Rails.logger.info "Using rsvg-convert for SVG conversion"

        # First pass: Convert at high resolution for quality
        temp_high_res = Tempfile.new([ "high_res", ".png" ])
        rsvg_cmd = [
          "rsvg-convert",
          "--keep-aspect-ratio",
          "--width", (LOGO_MAX_WIDTH * 2).to_s,  # 2x for better quality
          "--height", (LOGO_MAX_HEIGHT * 2).to_s,
          "--background-color", "transparent",
          svg_file.path,
          "--output", temp_high_res.path
        ]

        if system(*rsvg_cmd, err: File::NULL)
          # Second pass: Convert to WebP and resize to fit within bounds
          resize_cmd = [
            "convert",
            temp_high_res.path,
            "-resize", "#{LOGO_MAX_WIDTH}x#{LOGO_MAX_HEIGHT}>",  # Shrink to fit
            "-filter", "Lanczos",
            "-quality", "95",
            "-background", "none",
            "-gravity", "center",
            "-define", "webp:method=6",
            "-define", "webp:alpha-quality=100",
            "webp:#{logo_file.path}"
          ]

          if system(*resize_cmd)
            converted = true
            Rails.logger.info "Successfully converted SVG using rsvg-convert"
          end
        end

        temp_high_res.close
        temp_high_res.unlink
      end

      # Method 2: Fall back to ImageMagick
      unless converted
        Rails.logger.info "Using ImageMagick for SVG conversion"

        svg_to_webp_cmd = [
          "convert",
          "-background", "none",
          "-density", "300",  # Higher density for better quality
          svg_file.path,
          "-resize", "#{LOGO_MAX_WIDTH}x#{LOGO_MAX_HEIGHT}>",  # Shrink to fit
          "-filter", "Lanczos",
          "-quality", "95",
          "-gravity", "center",
          "-define", "webp:method=6",
          "-define", "webp:alpha-quality=100",
          "webp:#{logo_file.path}"
        ]

        unless system(*svg_to_webp_cmd)
          Rails.logger.error "Failed to convert SVG to WebP with both methods"
          return nil
        end
      end

      # Get dimensions of the converted logo
      require "open3"
      stdout, status = Open3.capture2("identify", "-format", "%wx%h", logo_file.path)
      unless status.success?
        Rails.logger.error "Failed to get image dimensions"
        return nil
      end
      dimensions = stdout.strip
      logo_width, logo_height = dimensions.split("x").map(&:to_i)

      # Calculate position to center logo on template
      x_offset = LOGO_CENTER_X - (logo_width / 2)
      y_offset = LOGO_CENTER_Y - (logo_height / 2)

      # Composite logo onto template using ImageMagick
      composite_cmd = [
        "convert",
        template_path.to_s,
        logo_file.path,
        "-geometry", "+#{x_offset}+#{y_offset}",
        "-composite",
        "-quality", "95",
        "-define", "webp:method=4",
        "webp:#{output_file.path}"
      ]

      unless system(*composite_cmd)
        Rails.logger.error "Failed to composite images"
        return nil
      end

      # Read and return raw WebP data
      File.read(output_file.path)

    rescue => e
      Rails.logger.error "Failed to generate success story image: #{e.message}"
      nil
    ensure
      svg_file.close
      svg_file.unlink
      logo_file.close
      logo_file.unlink
      output_file.close
      output_file.unlink
    end
  end

  # Alternative method to just convert SVG to WebP without template
  def svg_to_webp
    svg_file = Tempfile.new([ "logo", ".svg" ])
    webp_file = Tempfile.new([ "logo", ".webp" ])

    begin
      svg_file.write(@post.logo_svg)
      svg_file.rewind

      # Dual approach for simple conversion too
      converted = false

      # Try rsvg-convert first
      if system("which", "rsvg-convert", out: File::NULL, err: File::NULL)
        # First convert to PNG with rsvg-convert
        temp_png = Tempfile.new([ "temp", ".png" ])
        rsvg_cmd = [
          "rsvg-convert",
          "--keep-aspect-ratio",
          "--background-color", "transparent",
          svg_file.path,
          "--output", temp_png.path
        ]

        if system(*rsvg_cmd, err: File::NULL)
          # Then convert PNG to WebP
          png_to_webp_cmd = [
            "convert",
            temp_png.path,
            "-quality", "95",
            "-define", "webp:method=6",
            "-define", "webp:alpha-quality=100",
            "webp:#{webp_file.path}"
          ]

          if system(*png_to_webp_cmd)
            converted = true
          end
        end

        temp_png.close
        temp_png.unlink
      end

      # Fall back to direct ImageMagick conversion
      unless converted
        convert_cmd = [
          "convert",
          "-background", "none",
          "-density", "300",
          svg_file.path,
          "-quality", "95",
          "-define", "webp:method=6",
          "-define", "webp:alpha-quality=100",
          "webp:#{webp_file.path}"
        ]

        unless system(*convert_cmd)
          Rails.logger.error "Failed to convert SVG to WebP"
          return nil
        end
      end

      # Return raw WebP data
      File.read(webp_file.path)
    rescue => e
      Rails.logger.error "Failed to convert SVG to WebP: #{e.message}"
      nil
    ensure
      svg_file.close
      svg_file.unlink
      webp_file.close
      webp_file.unlink
    end
  end
end
