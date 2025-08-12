class SvgSanitizer
  # This sanitizer ensures SVGs are safe and cross-platform compatible
  #
  # IMPORTANT: SVG Case Sensitivity
  # SVG attributes are case-sensitive per the spec. Many SVG editors output incorrect
  # lowercase versions (e.g., 'viewbox' instead of 'viewBox'). While macOS may be forgiving,
  # Linux strictly enforces case sensitivity, causing SVGs to break on production servers.
  # We fix these case issues BEFORE saving to the database to ensure consistency.

  # Allowed SVG elements
  ALLOWED_ELEMENTS = %w[
    svg g path rect circle ellipse line polyline polygon text tspan textPath
    defs pattern clipPath mask linearGradient radialGradient stop symbol use
    image desc title metadata
  ].freeze

  # Allowed attributes (no event handlers)
  # Note: These should be lowercase for comparison
  # width and height are intentionally excluded to allow proper responsive scaling
  ALLOWED_ATTRIBUTES = %w[
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

  # Fix common SVG case sensitivity issues
  # Many SVG editors output incorrect case for attributes, which breaks on Linux
  def self.fix_svg_case_sensitivity(svg_content)
    return svg_content if svg_content.blank?

    fixed = svg_content.dup

    # Most common problematic attributes
    fixed.gsub!(/\bviewbox=/i, "viewBox=")
    fixed.gsub!(/\bpreserveaspectratio=/i, "preserveAspectRatio=")

    # Gradient-related attributes
    fixed.gsub!(/\bgradientunits=/i, "gradientUnits=")
    fixed.gsub!(/\bgradienttransform=/i, "gradientTransform=")

    # Pattern-related attributes
    fixed.gsub!(/\bpatternunits=/i, "patternUnits=")
    fixed.gsub!(/\bpatterntransform=/i, "patternTransform=")

    # Other common camelCase attributes
    fixed.gsub!(/\bclippath=/i, "clipPath=")
    fixed.gsub!(/\btextlength=/i, "textLength=")
    fixed.gsub!(/\blengthadjust=/i, "lengthAdjust=")
    fixed.gsub!(/\bbaseprofile=/i, "baseProfile=")

    # Marker-related attributes
    fixed.gsub!(/\bmarkerwidth=/i, "markerWidth=")
    fixed.gsub!(/\bmarkerheight=/i, "markerHeight=")
    fixed.gsub!(/\bmarkerunits=/i, "markerUnits=")

    # Reference attributes
    fixed.gsub!(/\brefx=/i, "refX=")
    fixed.gsub!(/\brefy=/i, "refY=")

    # Path and stroke attributes
    fixed.gsub!(/\bpathlength=/i, "pathLength=")
    fixed.gsub!(/\bstrokedasharray=/i, "strokeDasharray=")
    fixed.gsub!(/\bstrokedashoffset=/i, "strokeDashoffset=")
    fixed.gsub!(/\bstrokelinecap=/i, "strokeLinecap=")
    fixed.gsub!(/\bstrokelinejoin=/i, "strokeLinejoin=")
    fixed.gsub!(/\bstrokemiterlimit=/i, "strokeMiterlimit=")

    fixed
  end

  # Fix viewBox positioning issues
  # Some SVGs have offset viewBox values (e.g., "0 302.1 612 192") that cause content
  # to render outside the visible area. We normalize these to start at 0,0.
  #
  # NOTE: This is conservative - only fixes when offset is likely problematic:
  # - Y offset > height (content completely above visible area)
  # - X offset > width (content completely to the left of visible area)
  def self.fix_viewbox_offset(svg_content)
    return svg_content if svg_content.blank?

    # Match viewBox attribute
    if svg_content =~ /viewBox\s*=\s*["']([^"']+)["']/i
      viewbox_value = $1
      values = viewbox_value.split(/\s+/).map(&:to_f)

      if values.length == 4
        x_offset, y_offset, width, height = values

        # Only fix if offset seems problematic (content likely outside visible area)
        # This preserves intentional offsets for sprites, artistic crops, etc.
        if y_offset > height || x_offset > width || y_offset > 100
          # Create new viewBox starting at 0,0
          new_viewbox = "0 0 #{width} #{height}"

          # Replace the viewBox
          fixed_svg = svg_content.gsub(/viewBox\s*=\s*["'][^"']+["']/i, "viewBox=\"#{new_viewbox}\"")

          # Add a transform to the SVG content to compensate for the offset
          # This moves all content up/left by the offset amount
          if x_offset != 0 || y_offset != 0
            # Add transform to the first <svg> tag
            fixed_svg = fixed_svg.sub(/<svg([^>]*)>/i) do |match|
              attrs = $1
              # Check if there's already a transform
              if attrs =~ /transform\s*=/i
                # Prepend to existing transform
                attrs.sub!(/transform\s*=\s*["']([^"']+)["']/i) do |t|
                  "transform=\"translate(#{-x_offset} #{-y_offset}) #{$1}\""
                end
                "<svg#{attrs}>"
              else
                # Add new transform
                "<svg#{attrs} transform=\"translate(#{-x_offset} #{-y_offset})\">"
              end
            end
          end

          return fixed_svg
        end
      end
    end

    svg_content
  end

  def self.sanitize(svg_content)
    return "" if svg_content.blank?

    # Fix common SVG case sensitivity issues FIRST
    # Many SVG editors output incorrect case for attributes, which breaks on Linux
    svg_content = fix_svg_case_sensitivity(svg_content)

    # NOTE: We DON'T automatically fix viewBox offsets as they may be intentional for:
    # - Icon sprites/atlases (showing specific regions)
    # - Artistic cropping
    # - Animation preparation
    # - Print bleeds
    # - Technical diagrams with specific coordinate systems
    # Uncomment the line below only if you're having issues with offset viewBoxes:
    # svg_content = fix_viewbox_offset(svg_content)

    # Remove any dangerous patterns
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

    # Store original dimensions before cleaning for viewBox calculation
    original_width = svg_element["width"]
    original_height = svg_element["height"]

    # Also clean the SVG element itself
    svg_element.attributes.keys.each do |name|
      unless ALLOWED_ATTRIBUTES.include?(name.downcase)
        svg_element.remove_attribute(name)
      end
    end

    # Ensure SVG has a viewBox for proper scaling
    # If no viewBox exists but we had width/height, create one
    if svg_element["viewBox"].blank? && svg_element["viewbox"].blank?
      if original_width && original_height
        # Extract numeric values from width/height (remove px, %, etc)
        width_val = original_width.to_s.gsub(/[^\d.]/, "").to_f
        height_val = original_height.to_s.gsub(/[^\d.]/, "").to_f

        if width_val > 0 && height_val > 0
          svg_element["viewBox"] = "0 0 #{width_val} #{height_val}"
        end
      end
    end

    # Return the cleaned SVG
    svg_element.to_html
  end
end
