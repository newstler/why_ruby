class SuccessStoryImageGenerator
  TEMPLATE_PATH = Rails.root.join("app", "assets", "images", "success_story_teplate.png")

  # NOTE: This service uses either rsvg-convert (preferred) or ImageMagick's 'convert' command
  # For best results, especially with complex SVGs like Shopify's logo:
  #   - Ubuntu/Debian: sudo apt-get install librsvg2-bin
  #   - Mac: brew install librsvg
  # Falls back to ImageMagick if rsvg-convert is not available
  #
  # QUALITY STRATEGY: Render at 4x resolution (4608x2160) then downsample to 1152x540
  # This ensures maximum sharpness and quality in the final image

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
    png_base64 = generate_social_image

    # Store the generated PNG
    @post.update_column(:logo_png_base64, png_base64) if png_base64.present?
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

      # Try rsvg-convert first (better SVG handling), fallback to ImageMagick
      if system("which rsvg-convert > /dev/null 2>&1")
        # Use rsvg-convert for better SVG rendering (handles viewBox correctly)
        Rails.logger.info "Using rsvg-convert for SVG conversion"

        # SIMPLE APPROACH: Render at 4x resolution for super high quality
        # The template area is 1152x540, so render at 4608x2160 then scale down

        temp_highres = Tempfile.new([ "logo_highres", ".png" ])

        # Render at 4x size for maximum quality
        rsvg_cmd = [
          "rsvg-convert",
          "-w", "1152",                 # 4x width for super high quality
          "-h", "540",                 # 4x height for super high quality
          "--keep-aspect-ratio",        # Maintain aspect ratio
          "-f", "png",
          "-o", temp_highres.path,
          svg_file.path
        ]

        if system(*rsvg_cmd)
          # Now trim excess transparent space and resize to target
          convert_cmd = [
            "convert",
            temp_highres.path,
            "-trim", "+repage",         # Remove transparent padding
            "-interpolate", "catrom",   # High-quality interpolation
            "-filter", "Lanczos",       # High quality downsampling
            "-resize", "1152x540",      # Scale to target size
            # "-unsharp", "0x2+1+0",      # Strong unsharp mask for crisp edges
            "-quality", "100",          # Max quality
            "-depth", "8",              # 8-bit per channel
            "PNG32:" + png_file.path    # 32-bit PNG with alpha
          ]

          system(*convert_cmd)
          temp_highres.close
          temp_highres.unlink
        else
          Rails.logger.error "rsvg-convert failed, falling back to ImageMagick"
        end
      end

      # Fallback to ImageMagick if rsvg-convert not available or failed
      if !File.exist?(png_file.path) || File.zero?(png_file.path)
        Rails.logger.info "Using ImageMagick for SVG conversion"

        # Use ImageMagick with super high-resolution rendering
        # Render at very high DPI, then scale down for best quality
        svg_to_png_cmd = [
          "convert",
          "-density", "2400",          # Ultra high DPI (8x normal)
          "-background", "none",        # Transparent background
          svg_file.path,
          "-resize", "4608x2160",       # First resize to 4x target
          "-trim", "+repage",           # Trim transparent areas
          "-interpolate", "catrom",    # High-quality interpolation
          "-filter", "Lanczos",         # High quality filter
          "-resize", "1152x540",        # Final resize to target
          "-unsharp", "0x2+1+0",        # Strong unsharp mask for crisp edges
          "-quality", "100",            # Maximum quality
          "-depth", "8",                # 8-bit per channel
          "PNG32:" + png_file.path      # 32-bit PNG with alpha
        ]

        unless system(*svg_to_png_cmd)
          Rails.logger.error "Failed to convert SVG to PNG"
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

      # Calculate position to center logo at 960x432 on 1920x1080 template
      x_offset = 960 - (logo_width / 2)
      y_offset = 432 - (logo_height / 2)

      # Composite logo onto template using ImageMagick
      # Ensure proper alpha compositing to avoid black borders
      composite_cmd = [
        "convert",
        TEMPLATE_PATH.to_s,
        png_file.path,
        "-geometry", "+#{x_offset}+#{y_offset}",
        "-compose", "over",     # Use "over" compositing to preserve transparency
        "-composite",
        "-quality", "100",      # Maximum quality for final output
        output_file.path
      ]

      unless system(*composite_cmd)
        Rails.logger.error "Failed to composite images"
        return nil
      end

      # Read and encode to base64
      image_data = File.read(output_file.path)
      "data:image/png;base64,#{Base64.strict_encode64(image_data)}"

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
  def svg_to_png_base64
    svg_file = Tempfile.new([ "logo", ".svg" ])
    png_file = Tempfile.new([ "logo", ".png" ])

    begin
      svg_file.write(@post.logo_svg)
      svg_file.rewind

      # Simple SVG to PNG conversion
      convert_cmd = [
        "convert",
        "-background", "none",
        svg_file.path,
        png_file.path
      ]

      unless system(*convert_cmd)
        Rails.logger.error "Failed to convert SVG to PNG"
        return nil
      end

      image_data = File.read(png_file.path)
      "data:image/png;base64,#{Base64.strict_encode64(image_data)}"
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
