# frozen_string_literal: true

module Post::OgImageGeneratable
  extend ActiveSupport::Concern

  OG_TEMPLATE_PATH = Rails.root.join("app", "assets", "images", "success_story_template.webp")
  OG_LOGO_MAX_WIDTH = 410
  OG_LOGO_MAX_HEIGHT = 190
  OG_LOGO_CENTER_X = 410
  OG_LOGO_CENTER_Y = 145

  # Generate OG image by overlaying SVG logo on success story template
  def generate_og_image!(force: false)
    return unless success_story? && logo_svg.present?
    return unless system("which", "convert", out: File::NULL, err: File::NULL)

    if force && featured_image.attached?
      featured_image.purge
    end

    return if !force && featured_image.attached?

    webp_data = composite_logo_on_template
    return unless webp_data && !webp_data.empty?

    featured_image.attach(
      io: StringIO.new(webp_data),
      filename: "#{slug}-social.webp",
      content_type: "image/webp"
    )

    process_image_variants! if featured_image.attached?
  end

  private

  def composite_logo_on_template
    svg_file = Tempfile.new([ "logo", ".svg" ])
    logo_file = Tempfile.new([ "logo_converted", ".webp" ])
    output_file = Tempfile.new([ "success_story", ".webp" ])

    begin
      svg_file.write(logo_svg)
      svg_file.rewind

      return nil unless File.exist?(OG_TEMPLATE_PATH)

      converted = try_rsvg_convert(svg_file.path, logo_file.path) ||
                  try_imagemagick_convert(svg_file.path, logo_file.path)

      return nil unless converted

      require "open3"
      stdout, status = Open3.capture2("identify", "-format", "%wx%h", logo_file.path)
      return nil unless status.success?

      logo_width, logo_height = stdout.strip.split("x").map(&:to_i)
      x_offset = OG_LOGO_CENTER_X - (logo_width / 2)
      y_offset = OG_LOGO_CENTER_Y - (logo_height / 2)

      composite_cmd = [
        "convert", OG_TEMPLATE_PATH.to_s, logo_file.path,
        "-geometry", "+#{x_offset}+#{y_offset}",
        "-composite", "-quality", "95",
        "-define", "webp:method=4",
        "webp:#{output_file.path}"
      ]

      return nil unless system(*composite_cmd)

      File.read(output_file.path)
    rescue => e
      Rails.logger.error "Failed to generate success story image: #{e.message}"
      nil
    ensure
      [ svg_file, logo_file, output_file ].each { |f| f.close; f.unlink }
    end
  end

  def try_rsvg_convert(svg_path, output_path)
    return false unless system("which", "rsvg-convert", out: File::NULL, err: File::NULL)

    temp_high_res = Tempfile.new([ "high_res", ".png" ])

    begin
      rsvg_cmd = [
        "rsvg-convert", "--keep-aspect-ratio",
        "--width", (OG_LOGO_MAX_WIDTH * 2).to_s,
        "--height", (OG_LOGO_MAX_HEIGHT * 2).to_s,
        "--background-color", "transparent",
        svg_path, "--output", temp_high_res.path
      ]

      return false unless system(*rsvg_cmd, err: File::NULL)

      resize_cmd = [
        "convert", temp_high_res.path,
        "-resize", "#{OG_LOGO_MAX_WIDTH}x#{OG_LOGO_MAX_HEIGHT}>",
        "-filter", "Lanczos", "-quality", "95",
        "-background", "none", "-gravity", "center",
        "-define", "webp:method=6", "-define", "webp:alpha-quality=100",
        "webp:#{output_path}"
      ]

      system(*resize_cmd)
    ensure
      temp_high_res.close
      temp_high_res.unlink
    end
  end

  def try_imagemagick_convert(svg_path, output_path)
    cmd = [
      "convert", "-background", "none", "-density", "300",
      svg_path,
      "-resize", "#{OG_LOGO_MAX_WIDTH}x#{OG_LOGO_MAX_HEIGHT}>",
      "-filter", "Lanczos", "-quality", "95",
      "-gravity", "center",
      "-define", "webp:method=6", "-define", "webp:alpha-quality=100",
      "webp:#{output_path}"
    ]

    system(*cmd)
  end
end
