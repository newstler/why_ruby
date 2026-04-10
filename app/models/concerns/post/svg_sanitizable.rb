module Post::SvgSanitizable
  extend ActiveSupport::Concern

  # Allowed SVG elements
  ALLOWED_SVG_ELEMENTS = %w[
    svg g path rect circle ellipse line polyline polygon text tspan textPath
    defs pattern clipPath mask linearGradient radialGradient stop symbol use
    image desc title metadata
  ].freeze

  # Allowed attributes (no event handlers)
  ALLOWED_SVG_ATTRIBUTES = %w[
    style class
    viewbox preserveaspectratio
    x y x1 y1 x2 y2 cx cy r rx ry
    d points fill stroke stroke-width stroke-linecap stroke-linejoin
    fill-opacity stroke-opacity opacity
    transform translate rotate scale
    font-family font-size font-weight text-anchor
    href xlink:href
    offset stop-color stop-opacity
    gradientunits gradienttransform
    patternunits patterntransform
    clip-path mask
    xmlns xmlns:xlink version
  ].map(&:downcase).freeze

  DANGEROUS_SVG_PATTERNS = [
    /<script[\s>]/i,
    /<\/script>/i,
    /javascript:/i,
    /on\w+\s*=/i,
    /data:text\/html/i,
    /vbscript:/i,
    /behavior:/i,
    /expression\(/i,
    /-moz-binding:/i
  ].freeze

  # Sanitize the logo_svg attribute in place
  def sanitize_logo_svg!
    return if logo_svg.blank?

    self.logo_svg = self.class.sanitize_svg(logo_svg)
  end

  class_methods do
    def sanitize_svg(svg_content)
      return "" if svg_content.blank?

      svg_content = fix_svg_case_sensitivity(svg_content)

      DANGEROUS_SVG_PATTERNS.each do |pattern|
        svg_content = svg_content.gsub(pattern, "")
      end

      begin
        doc = Nokogiri::XML::DocumentFragment.parse(svg_content) do |config|
          config.nonet
          config.noent
        end
      rescue => e
        Rails.logger.error "Failed to parse SVG: #{e.message}"
        return ""
      end

      svg_element = if doc.children.any? { |c| c.name.downcase == "svg" }
                      doc.children.find { |c| c.name.downcase == "svg" }
      else
                      doc.at_css("svg") || doc.at_xpath("//svg")
      end

      return "" unless svg_element

      svg_element.css("*").each do |element|
        unless ALLOWED_SVG_ELEMENTS.include?(element.name.downcase)
          element.remove
          next
        end

        element.attributes.keys.each do |name|
          unless ALLOWED_SVG_ATTRIBUTES.include?(name.downcase)
            element.remove_attribute(name)
          end
        end

        if element["style"]&.match?(/javascript:|expression\(|behavior:|binding:|@import/i)
          element.remove_attribute("style")
        end

        %w[href xlink:href].each do |attr|
          if element[attr]&.match?(/^javascript:/i)
            element.remove_attribute(attr)
          end
        end
      end

      original_width = svg_element["width"]
      original_height = svg_element["height"]

      svg_element.attributes.keys.each do |name|
        unless ALLOWED_SVG_ATTRIBUTES.include?(name.downcase)
          svg_element.remove_attribute(name)
        end
      end

      if svg_element["viewBox"].blank? && svg_element["viewbox"].blank?
        if original_width && original_height
          width_val = original_width.to_s.gsub(/[^\d.]/, "").to_f
          height_val = original_height.to_s.gsub(/[^\d.]/, "").to_f

          if width_val > 0 && height_val > 0
            svg_element["viewBox"] = "0 0 #{width_val} #{height_val}"
          end
        end
      end

      svg_element.to_xml
    end

    private

    def fix_svg_case_sensitivity(svg_content)
      fixed = svg_content.dup
      fixed.gsub!(/\bviewbox=/i, "viewBox=")
      fixed.gsub!(/\bpreserveaspectratio=/i, "preserveAspectRatio=")
      fixed.gsub!(/\bgradientunits=/i, "gradientUnits=")
      fixed.gsub!(/\bgradienttransform=/i, "gradientTransform=")
      fixed.gsub!(/\bpatternunits=/i, "patternUnits=")
      fixed.gsub!(/\bpatterntransform=/i, "patternTransform=")
      fixed.gsub!(/\bclippath=/i, "clipPath=")
      fixed.gsub!(/\btextlength=/i, "textLength=")
      fixed.gsub!(/\blengthadjust=/i, "lengthAdjust=")
      fixed.gsub!(/\bbaseprofile=/i, "baseProfile=")
      fixed.gsub!(/\bmarkerwidth=/i, "markerWidth=")
      fixed.gsub!(/\bmarkerheight=/i, "markerHeight=")
      fixed.gsub!(/\bmarkerunits=/i, "markerUnits=")
      fixed.gsub!(/\brefx=/i, "refX=")
      fixed.gsub!(/\brefy=/i, "refY=")
      fixed.gsub!(/\bpathlength=/i, "pathLength=")
      fixed.gsub!(/\bstrokedasharray=/i, "strokeDasharray=")
      fixed.gsub!(/\bstrokedashoffset=/i, "strokeDashoffset=")
      fixed.gsub!(/\bstrokelinecap=/i, "strokeLinecap=")
      fixed.gsub!(/\bstrokelinejoin=/i, "strokeLinejoin=")
      fixed.gsub!(/\bstrokemiterlimit=/i, "strokeMiterlimit=")
      fixed
    end
  end
end
