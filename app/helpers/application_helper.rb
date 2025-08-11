module ApplicationHelper
  def markdown_to_html(markdown_text)
    return "" if markdown_text.blank?

    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: true,
      link_attributes: { rel: "nofollow", target: "_blank" }
    )

    markdown = Redcarpet::Markdown.new(renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      disable_indented_code_blocks: true,
      strikethrough: true,
      lax_spacing: true,
      space_after_headers: true,
      superscript: true,
      underline: true,
      highlight: true,
      quote: true,
      footnotes: true
    )

    # Render markdown and apply syntax highlighting
    html = markdown.render(markdown_text)

    # Apply syntax highlighting to code blocks
    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    doc.css("pre code").each do |code_block|
      # Extract language from class attribute (e.g., "ruby" from class="ruby" or "language-ruby")
      language_class = code_block["class"] || ""
      language = language_class.gsub(/^(language-)?/, "") || "text"

      begin
        lexer = Rouge::Lexer.find(language) || Rouge::Lexers::PlainText.new
        # Use inline styles instead of CSS classes for more reliable styling
        theme = Rouge::Themes::Github.new
        formatter = Rouge::Formatters::HTMLInline.new(theme)
        highlighted_code = formatter.format(lexer.lex(code_block.text))

        # Create a new pre element with the highlight class
        pre_element = code_block.parent
        pre_element["class"] = "highlight highlight-#{language}"

        # Replace the code block's content with the highlighted version
        code_block.inner_html = highlighted_code
      rescue => e
        # If highlighting fails, keep the original code block
        Rails.logger.error "Syntax highlighting failed for language '#{language}': #{e.message}"
      end
    end

    doc.to_html
  end

  def format_post_date(date)
    if date.year == Date.current.year
      date.strftime("%B %d")
    else
      date.strftime("%B %d, %Y")
    end
  end

  def format_comment_date(date)
    time_ago_in_words(date) + " ago"
  end

  def format_short_date(date)
    if date.year == Date.current.year
      date.strftime("%b %d")
    else
      date.strftime("%b %d, %Y")
    end
  end

  def post_link_url(post)
    post.link? ? safe_external_url(post.url) : post_path(post)
  end

  def post_link_options(post)
    post.link? ? { target: "_blank", rel: "noopener" } : {}
  end

  def extract_domain(url)
    return nil if url.blank?

    begin
      uri = URI.parse(url)
      host = uri.host || ""
      # Remove www. prefix if present
      host.sub(/^www\./, "")
    rescue URI::InvalidURIError
      nil
    end
  end

  def category_menu_active?(category)
    # Highlight if on the category page itself
    return true if current_page?(category_path(category))

    # Highlight if viewing a post that belongs to this category
    if controller_name == "posts" && action_name == "show" && @post.present?
      return @post.category_id == category.id
    end

    false
  end

  def success_stories_menu_active?
    # Highlight if on the success stories page
    return true if controller_name == "posts" && action_name == "success_stories"

    # Highlight if viewing a success story post
    if controller_name == "posts" && action_name == "show" && @post.present?
      return @post.success_story?
    end

    false
  end

  def community_menu_active?
    # Highlight if on the users index page
    return true if current_page?(users_path)

    # Highlight if viewing a user profile
    controller_name == "users" && action_name == "show"
  end

  def safe_external_url(url)
    return "#" if url.blank?

    # Parse the URL and validate it
    begin
      uri = URI.parse(url)

      # Only allow http, https, and mailto schemes
      allowed_schemes = %w[http https mailto]
      return "#" unless allowed_schemes.include?(uri.scheme&.downcase)

      # Return the original URL if it's safe
      url
    rescue URI::InvalidURIError
      # If the URL is invalid, return a safe fallback
      "#"
    end
  end

  def safe_svg_content(svg_content)
    # This helper makes it explicit that SVG content has been sanitized
    # The actual sanitization happens in the model via SvgSanitizer
    # The SVG is already sanitized, so we can safely mark it as html_safe
    return "" if svg_content.blank?
    svg_content.html_safe
  end

  def safe_markdown_content(markdown_text)
    # This helper makes it explicit that markdown has been safely rendered
    # with HTML filtering enabled
    markdown_to_html(markdown_text).html_safe
  end
end
