class SvgSanitizer
  # Allowed SVG elements
  ALLOWED_ELEMENTS = %w[
    svg g path rect circle ellipse line polyline polygon text tspan textPath
    defs pattern clipPath mask linearGradient radialGradient stop symbol use
    image desc title metadata
  ].freeze

  # Allowed attributes (no event handlers)
  # Note: These should be lowercase for comparison
  ALLOWED_ATTRIBUTES = %w[
    id class style
    width height viewbox preserveaspectratio
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

  # Dangerous patterns to remove
  DANGEROUS_PATTERNS = [
    /<script[\s>]/i,
    /<\/script>/i,
    /javascript:/i,
    /on\w+\s*=/i,  # Event handlers like onclick, onload, etc.
    /data:text\/html/i,
    /vbscript:/i,
    /behavior:/i,
    /expression\(/i,
    /-moz-binding:/i
  ].freeze

  def self.sanitize(svg_content)
    return "" if svg_content.blank?

    # Remove any dangerous patterns first
    DANGEROUS_PATTERNS.each do |pattern|
      svg_content = svg_content.gsub(pattern, "")
    end

    # Parse the SVG - use HTML parsing mode for better compatibility
    begin
      doc = Nokogiri::HTML::DocumentFragment.parse(svg_content)
    rescue => e
      Rails.logger.error "Failed to parse SVG: #{e.message}"
      return ""
    end

    # Find SVG elements first
    svg_elements = doc.css("svg")
    return "" if svg_elements.empty?
    
    svg_element = svg_elements.first
    
    # Process all elements within the SVG
    svg_element.css("*").each do |element|
      unless ALLOWED_ELEMENTS.include?(element.name.downcase)
        element.remove
        next
      end

      # Remove all attributes that aren't in our allowlist
      element.attributes.keys.each do |name|
        unless ALLOWED_ATTRIBUTES.include?(name.downcase)
          element.remove_attribute(name)
        end
      end

      # Additional check for style attribute
      if element["style"]
        # Remove any dangerous CSS properties
        style = element["style"]
        if style =~ /javascript:|expression\(|behavior:|binding:|@import/i
          element.remove_attribute("style")
        end
      end

      # Check href attributes for javascript: protocol
      %w[href xlink:href].each do |attr|
        if element[attr] && element[attr] =~ /^javascript:/i
          element.remove_attribute(attr)
        end
      end
    end
    
    # Also clean the SVG element itself
    svg_element.attributes.keys.each do |name|
      unless ALLOWED_ATTRIBUTES.include?(name.downcase)
        svg_element.remove_attribute(name)
      end
    end

    # Return the cleaned SVG
    svg_element.to_html
  end
end
