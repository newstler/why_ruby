module ApplicationHelper
  include ImageHelper

  # Get client country code for analytics (ISO 3166-1 alpha-2, e.g., "US", "DE", "CA")
  def client_country_code
    return @client_country_code if defined?(@client_country_code)

    @client_country_code = begin
      result = Geocoder.search(request.remote_ip).first
      result&.country_code&.upcase
    rescue => e
      Rails.logger.warn "Geocoder lookup failed: #{e.message}"
      nil
    end
  end
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
        formatter = Rouge::Formatters::HTML.new
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
    if post.link?
      safe_external_url(post.url)
    else
      # In production, always link to primary domain for posts
      if Rails.env.production?
        primary_domain_post_url(post)
      else
        post_path_for(post)
      end
    end
  end

  # Generate full URL to post on primary domain (whyruby.info)
  # Used to ensure posts always link to the content domain, not the community domain
  def primary_domain_post_url(post)
    domain = Rails.application.config.x.domains.primary
    "https://#{domain}/#{post.category.to_param}/#{post.to_param}"
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

  # Since success stories now work like regular categories, we can remove this method
  # and just use category_menu_active? for success stories too

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

  def has_success_stories?
    # Cache the result for the request to avoid multiple DB queries
    if Category.success_story_category
      @has_success_stories ||= Category.success_story_category.posts.published.exists?
    else
      @has_success_stories ||= Post.success_stories.published.exists?
    end
  end

  def should_show_mobile_cta?
    # Show CTA when nav is collapsed (below lg) if user is not signed in
    # or if their testimonial is not published
    return true unless user_signed_in?

    # Check if user has a published testimonial
    !current_user.testimonial&.published?
  end

  # Generate the full formatted page title that matches the <title> tag format
  def full_page_title(page_title = nil)
    if page_title.present?
      "Why Ruby? — #{page_title}"
    else
      "Why Ruby?"
    end
  end

  # Generate versioned URL for OG image to bust social media caches
  # Pass a filename to use a different image (e.g., "og-image-community.png")
  def versioned_og_image_url(filename = "og-image.png")
    og_image_path = Rails.root.join("public", filename)
    version = File.exist?(og_image_path) ? File.mtime(og_image_path).to_i.to_s : Time.current.to_i.to_s
    "#{request.base_url}/#{filename}?v=#{version}"
  end

  # Generate the full page title for community pages (Ruby Community branding)
  def community_page_title(page_title = nil)
    if page_title.present?
      "Ruby Community — #{page_title}"
    else
      "Ruby Community"
    end
  end

  # URL helpers for the new routing structure
  def post_url_for(post)
    post_url(post.category, post)
  end

  def post_path_for(post)
    post_path(post.category, post)
  end

  # Cross-domain URL helper with session sync
  def cross_domain_url(domain_type, path = "/")
    return path unless Rails.env.production?

    domains = Rails.application.config.x.domains
    host = (domain_type == :primary) ? domains.primary : domains.community

    # If already on target domain, just return the path
    return path if request.host == host

    if user_signed_in?
      # Sync session to target domain (memoize token for this request)
      token = cross_domain_token_for_request
      "https://#{host}/auth/receive?token=#{token}&return_to=#{path}"
    else
      "https://#{host}#{path}"
    end
  end

  # Memoize token per request so multiple links use the same token
  def cross_domain_token_for_request
    @cross_domain_token ||= current_user.generate_cross_domain_token!
  end

  # Helper for community index URL (works in dev and prod)
  def community_index_url
    return users_path unless Rails.env.production?

    domain = Rails.application.config.x.domains.community

    # In production on community domain, just go to root
    return "/" if request.host == domain

    # On primary domain, cross-domain to community
    if user_signed_in?
      token = current_user.generate_cross_domain_token!
      "https://#{domain}/auth/receive?token=#{token}&return_to=/"
    else
      "https://#{domain}/"
    end
  end

  # Helper for community index path with query params (for pagination/filtering)
  # On community domain in production, uses root path. Otherwise uses /community.
  def community_index_path(params = {})
    base_path = if Rails.env.production? && request.host == Rails.application.config.x.domains.community
      "/"
    else
      "/community"
    end

    return base_path if params.blank?

    query = params.compact.to_query
    query.present? ? "#{base_path}?#{query}" : base_path
  end

  # Helper for community user profile URLs (for navigation links)
  def community_user_url(user)
    if Rails.env.production?
      "https://#{Rails.application.config.x.domains.community}/#{user.to_param}"
    else
      user_path(user)
    end
  end

  # Canonical URL for community root (for meta tags)
  # Production: https://rubycommunity.org/
  # Development: http://localhost:3003/community
  def community_root_canonical_url
    if Rails.env.production?
      "https://#{Rails.application.config.x.domains.community}/"
    else
      users_url
    end
  end

  # Canonical URL for community user profile (for meta tags)
  # Production: https://rubycommunity.org/username
  # Development: http://localhost:3003/community/username
  def community_user_canonical_url(user)
    if Rails.env.production?
      "https://#{Rails.application.config.x.domains.community}/#{user.to_param}"
    else
      user_url(user)
    end
  end
end
