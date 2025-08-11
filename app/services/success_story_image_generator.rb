class SuccessStoryImageGenerator
  TEMPLATE_PATH = Rails.root.join("app", "assets", "images", "success_story_teplate.png")

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

      # Convert SVG to PNG with transparency using ImageMagick directly
      # -background none: transparent background
      # -density 300: high quality
      # -resize 1152x540>: max dimensions (only shrink if larger)
      svg_to_png_cmd = [
        "convert",
        "-background", "none",
        "-density", "300",
        svg_file.path,
        "-resize", "1152x540>",
        png_file.path
      ]

      unless system(*svg_to_png_cmd)
        Rails.logger.error "Failed to convert SVG to PNG"
        return nil
      end

      # Get dimensions of the converted logo
      dimensions_cmd = "identify -format '%wx%h' #{png_file.path}"
      dimensions = `#{dimensions_cmd}`.strip
      logo_width, logo_height = dimensions.split("x").map(&:to_i)

      # Calculate position to center logo at 960x432 on 1920x1080 template
      x_offset = 960 - (logo_width / 2)
      y_offset = 432 - (logo_height / 2)

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
