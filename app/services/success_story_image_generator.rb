class SuccessStoryImageGenerator
  TEMPLATE_PATH = Rails.root.join("app", "assets", "images", "success_story_teplate.png")

  # NOTE: This service uses ImageMagick's 'convert' command for compatibility with v6
  # which is commonly available on servers. The warnings about deprecated 'convert'
  # in development (if using v7) can be safely ignored.

  def initialize(post)
    @post = post
  end

  def generate!
    return unless @post.success_story? && @post.logo_svg.present?

    # Convert SVG logo to PNG and overlay on template
    png_base64 = generate_social_image

    # Store the generated PNG
    @post.update_column(:logo_png_base64, png_base64) if png_base64.present?
  end

  private

  def generate_social_image
    # Create temp file for SVG
    svg_file = Tempfile.new([ "logo", ".svg" ])
    svg_file.write(@post.logo_svg)
    svg_file.rewind

    # Create temp file for output
    output_file = Tempfile.new([ "success_story", ".png" ])

    begin
      # Load the template
      template = MiniMagick::Image.open(TEMPLATE_PATH)

      # Convert SVG to PNG with transparent background
      # Create a new PNG from SVG with transparency preserved
      svg_content = File.read(svg_file.path)

      # Create temporary PNG file
      png_file = Tempfile.new([ "logo_converted", ".png" ])

      # Use MiniMagick to convert with explicit transparency settings
      # Using Convert for ImageMagick v6 compatibility
      MiniMagick::Tool::Convert.new do |convert|
        convert.background "none"
        convert.density "300"  # Higher density for better quality
        convert << svg_file.path
        convert.resize "1152x540>"  # Maximum size: 1152px x 540px
        convert << png_file.path
      end

      logo = MiniMagick::Image.open(png_file.path)

      # Create a new image from template
      result = template.clone

      # Calculate position so logo center is at 960x432
      logo_width = logo.width
      logo_height = logo.height

      # Center of logo should be at 960x432 (template is 1920x1080)
      # This positions the logo center at exactly:
      # - Horizontal center: 960px (50% of 1920px width)
      # - Vertical position: 432px (40% of 1080px height)
      # So top-left corner should be at:
      x_offset = 960 - (logo_width / 2)
      y_offset = 432 - (logo_height / 2)

      # Composite the logo onto the template
      result = result.composite(logo) do |c|
        c.compose "Over"
        c.geometry "+#{x_offset}+#{y_offset}"
      end

      # Save to output file
      result.write(output_file.path)

      # Read and encode to base64
      image_data = File.read(output_file.path)
      "data:image/png;base64,#{Base64.strict_encode64(image_data)}"

    rescue => e
      Rails.logger.error "Failed to generate success story image: #{e.message}"
      nil
    ensure
      svg_file.close
      svg_file.unlink
      output_file.close
      output_file.unlink
      if defined?(png_file)
        png_file.close
        png_file.unlink
      end
    end
  end

  # Alternative method to just convert SVG to PNG without template
  def svg_to_png_base64
    svg_file = Tempfile.new([ "logo", ".svg" ])
    svg_file.write(@post.logo_svg)
    svg_file.rewind

    png_file = Tempfile.new([ "logo", ".png" ])

    begin
      image = MiniMagick::Image.open(svg_file.path)
      image.format "png"
      image.background "transparent"
      image.write(png_file.path)

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
