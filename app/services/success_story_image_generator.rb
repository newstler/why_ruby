class SuccessStoryImageGenerator
  TEMPLATE_PATH = Rails.root.join("app", "assets", "images", "success_story_template.png")

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

    # Convert SVG logo to PNG and overlay on template
    png_data = generate_social_image

    # Store the generated PNG in ActiveStorage
    if png_data && !png_data.empty?
      @post.featured_image.attach(
        io: StringIO.new(png_data),
        filename: "#{@post.slug}-social.png",
        content_type: "image/png"
      )
    end
  end

  private

  def generate_social_image
    # Create temp files
    svg_file = Tempfile.new([ "logo", ".svg" ])
    png_file = Tempfile.new([ "logo_converted", ".png" ])
    output_file = Tempfile.new([ "success_story", ".png" ])

    begin
      # Write SVG to file
      svg_file.write(@post.logo_svg)
      svg_file.rewind

      # Dual approach: Try rsvg-convert first (better SVG handling), fall back to ImageMagick
      converted = false

      # Method 1: Try rsvg-convert (preferred - no black border issues)
      if system("which", "rsvg-convert", out: File::NULL, err: File::NULL)
        Rails.logger.info "Using rsvg-convert for SVG conversion"

        # First pass: Convert at high resolution
        temp_high_res = Tempfile.new([ "high_res", ".png" ])
        rsvg_cmd = [
          "rsvg-convert",
          "--keep-aspect-ratio",
          "--width", "1728",  # 1.5x target width for better quality
          "--height", "810",  # 1.5x target height for better quality
          "--background-color", "transparent",
          svg_file.path,
          "--output", temp_high_res.path
        ]

        if system(*rsvg_cmd, err: File::NULL)
          # Second pass: Resize to target dimensions with high quality
          resize_cmd = [
            "convert",
            temp_high_res.path,
            "-resize", "686x320",  # Fit within box
            "-filter", "Lanczos",
            "-quality", "100",
            "-background", "none",
            "-gravity", "center",
            "-extent", "686x320",  # Canvas size
            "PNG32:#{png_file.path}"  # Force 32-bit PNG with alpha
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

        svg_to_png_cmd = [
          "convert",
          "-background", "none",
          "-density", "450",  # Higher density for better quality
          svg_file.path,
          "-resize", "686x320",  # Fit within box
          "-filter", "Lanczos",
          "-quality", "100",
          "-gravity", "center",
          "PNG32:#{png_file.path}"  # Force 32-bit PNG with alpha
        ]

        unless system(*svg_to_png_cmd)
          Rails.logger.error "Failed to convert SVG to PNG with both methods"
          return nil
        end
      end

      # Get dimensions of the converted logo
      # Use Open3 to safely execute the command and avoid command injection
      require "open3"
      stdout, status = Open3.capture2("identify", "-format", "%wx%h", png_file.path)
      unless status.success?
        Rails.logger.error "Failed to get image dimensions"
        return nil
      end
      dimensions = stdout.strip
      logo_width, logo_height = dimensions.split("x").map(&:to_i)

      # # Calculate position to center logo at 960x432 on 1920x1080 template
      # x_offset = 960 - (logo_width / 2)
      # y_offset = 386 - (logo_height / 2)
      # Calculate position to center logo at 960x432 on 1920x1080 template
      x_offset = 621 - (logo_width / 2)
      y_offset = 250 - (logo_height / 2)

      # Composite logo onto template using ImageMagick
      composite_cmd = [
        "convert",
        TEMPLATE_PATH.to_s,
        png_file.path,
        "-geometry", "+#{x_offset}+#{y_offset}",
        "-composite",
        output_file.path
      ]

      unless system(*composite_cmd)
        Rails.logger.error "Failed to composite images"
        return nil
      end

      # Read and return raw PNG data
      File.read(output_file.path)

    rescue => e
      Rails.logger.error "Failed to generate success story image: #{e.message}"
      nil
    ensure
      svg_file.close
      svg_file.unlink
      png_file.close
      png_file.unlink
      output_file.close
      output_file.unlink
    end
  end

  # Alternative method to just convert SVG to PNG without template
  def svg_to_png
    svg_file = Tempfile.new([ "logo", ".svg" ])
    png_file = Tempfile.new([ "logo", ".png" ])

    begin
      svg_file.write(@post.logo_svg)
      svg_file.rewind

      # Dual approach for simple conversion too
      converted = false

      # Try rsvg-convert first
      if system("which", "rsvg-convert", out: File::NULL, err: File::NULL)
        rsvg_cmd = [
          "rsvg-convert",
          "--keep-aspect-ratio",
          "--background-color", "transparent",
          svg_file.path,
          "--output", png_file.path
        ]

        if system(*rsvg_cmd, err: File::NULL)
          converted = true
        end
      end

      # Fall back to ImageMagick
      unless converted
        convert_cmd = [
          "convert",
          "-background", "none",
          "-density", "300",
          svg_file.path,
          "PNG32:#{png_file.path}"
        ]

        unless system(*convert_cmd)
          Rails.logger.error "Failed to convert SVG to PNG"
          return nil
        end
      end

      # Return raw PNG data
      File.read(png_file.path)
    rescue => e
      Rails.logger.error "Failed to convert SVG to PNG: #{e.message}"
      nil
    ensure
      svg_file.close
      svg_file.unlink
      png_file.close
      png_file.unlink
    end
  end
end
