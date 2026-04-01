module ApplicationHelper
  include ImageHelper

  # ── Open Graph helpers ──
  def og_title
    content_for(:og_title).presence || content_for(:title).presence || t("app_name", default: "Why Ruby?")
  end

  def og_description
    content_for(:og_description).presence || t("meta.default.summary", default: "")
  end

  def og_image
    if content_for?(:og_image)
      src = content_for(:og_image)
      src.start_with?("http") ? src : "#{request.base_url}#{src}"
    else
      versioned_og_image_url
    end
  end

  # Convert ISO country code to full name via i18n
  def country_name(code)
    return nil if code.blank?
    I18n.t("countries.#{code.upcase}", default: code)
  end

  # Extract country code from normalized location (e.g., "New York, US" -> "US")
  def country_code_from_location(normalized_location)
    return nil if normalized_location.blank?
    normalized_location.split(", ").last
  end

  # Get full country name from normalized location
  def country_name_from_location(normalized_location)
    code = country_code_from_location(normalized_location)
    country_name(code)
  end

  # ── Analytics ──

  def nullitics_enabled?
    Rails.configuration.x.nullitics rescue true
  end

  # Get client country code for analytics (ISO 3166-1 alpha-2, e.g., "US", "DE", "CA")
  def client_country_code
    return @client_country_code if defined?(@client_country_code)

    @client_country_code = Rails.cache.fetch("geo:#{request.remote_ip}", expires_in: 1.hour) do
      result = Geocoder.search(request.remote_ip).first
      result&.country_code&.upcase
    rescue => e
      Rails.logger.warn "Geocoder lookup failed: #{e.message}"
      nil
    end
  end

  # ── Markdown ──

  class MarkdownRenderer < Redcarpet::Render::HTML
    include Rouge::Plugins::Redcarpet

    def block_code(code, language)
      language ||= "text"
      formatter = Rouge::Formatters::HTMLLegacy.new(css_class: "highlight")
      lexer = Rouge::Lexer.find_fancy(language, code) || Rouge::Lexers::PlainText.new
      formatter.format(lexer.lex(code))
    end
  end

  # Class-level memoized markdown renderer for performance
  def self.markdown_renderer
    @markdown_renderer ||= begin
      renderer = MarkdownRenderer.new(
        filter_html: true,
        hard_wrap: true,
        link_attributes: { rel: "nofollow", target: "_blank" },
        fenced_code_blocks: true,
        prettify: true,
        tables: true,
        with_toc_data: true,
        no_intra_emphasis: true
      )

      Redcarpet::Markdown.new(renderer,
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
    end
  end

  def markdown(text)
    return "" if text.blank?
    ApplicationHelper.markdown_renderer.render(text).html_safe
  end

  def markdown_to_html(markdown_text)
    markdown(markdown_text)
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
  def primary_domain_post_url(post)
    domain = Rails.application.config.x.domains.primary
    "https://#{domain}/#{post.category.to_param}/#{post.to_param}"
  end

  # Generate edit post URL on primary domain
  def primary_domain_edit_post_url(post)
    if Rails.env.production?
      domain = Rails.application.config.x.domains.primary
      "https://#{domain}/posts/#{post.to_param}/edit"
    else
      edit_post_path(post)
    end
  end

  # Generate delete post URL on primary domain
  def primary_domain_destroy_post_url(post)
    if Rails.env.production?
      domain = Rails.application.config.x.domains.primary
      "https://#{domain}/posts/#{post.to_param}"
    else
      post_destroy_path(post)
    end
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

  def community_menu_active?
    return true if current_page?(users_path)
    controller_name == "users" && action_name == "show"
  end

  def safe_external_url(url)
    return "#" if url.blank?

    begin
      uri = URI.parse(url)
      allowed_schemes = %w[http https mailto]
      return "#" unless allowed_schemes.include?(uri.scheme&.downcase)
      url
    rescue URI::InvalidURIError
      "#"
    end
  end

  def safe_svg_content(svg_content)
    return "" if svg_content.blank?
    svg_content.html_safe
  end

  def safe_markdown_content(markdown_text)
    markdown_to_html(markdown_text).html_safe
  end

  # Linkify URLs and GitHub @mentions in user bio text
  def linkify_bio(text)
    return "" if text.blank?

    escaped = ERB::Util.html_escape(text)

    github_pattern = /(?<=\s|^)@([a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?)/
    url_pattern = %r{
      (?:https?://)?                    # Optional protocol
      (?:www\.)?                        # Optional www
      [a-zA-Z0-9][a-zA-Z0-9\-]*         # Domain name
      \.[a-zA-Z]{2,}                    # TLD
      (?:/[^\s,.<>]*)?                  # Optional path
    }x

    result = escaped.gsub(github_pattern) do |match|
      username = Regexp.last_match(1)
      %(<a href="https://github.com/#{username}" target="_blank" rel="noopener" class="underline hover:text-red-600 transition-colors">#{match}</a>)
    end

    result = result.gsub(url_pattern) do |match|
      next match if match.include?("github.com")
      url = match.start_with?("http") ? match : "https://#{match}"
      %(<a href="#{url}" target="_blank" rel="noopener" class="underline hover:text-red-600 transition-colors">#{match}</a>)
    end

    result.html_safe
  end

  def has_success_stories?
    if Category.success_story_category
      @has_success_stories ||= Category.success_story_category.posts.published.exists?
    else
      @has_success_stories ||= Post.success_stories.published.exists?
    end
  end

  def should_show_mobile_cta?
    return true unless user_signed_in?
    !current_user.testimonial&.published?
  end

  def full_page_title(page_title = nil)
    if page_title.present?
      "Why Ruby? — #{page_title}"
    else
      "Why Ruby?"
    end
  end

  # Cache OG image versions at boot time for performance
  OG_IMAGE_VERSIONS = Hash.new do |hash, filename|
    path = Rails.root.join("public", filename)
    hash[filename] = File.exist?(path) ? File.mtime(path).to_i.to_s : Time.current.to_i.to_s
  end

  def versioned_og_image_url(filename = "og-image.png")
    "#{request.base_url}/#{filename}?v=#{OG_IMAGE_VERSIONS[filename]}"
  end

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

    return path unless respond_to?(:request) && request.present? && request.env["warden"].present?

    domains = Rails.application.config.x.domains
    host = (domain_type == :primary) ? domains.primary : domains.community

    return path if request.host == host

    if user_signed_in?
      token = cross_domain_token_for_request
      "https://#{host}/auth/receive?token=#{token}&return_to=#{path}"
    else
      "https://#{host}#{path}"
    end
  end

  def cross_domain_token_for_request
    @cross_domain_token ||= current_user.generate_cross_domain_token!
  end

  def community_index_url
    return users_path unless Rails.env.production?

    domain = Rails.application.config.x.domains.community
    return "/" if request.host == domain

    if user_signed_in?
      token = current_user.generate_cross_domain_token!
      "https://#{domain}/auth/receive?token=#{token}&return_to=/"
    else
      "https://#{domain}/"
    end
  end

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

  def community_user_url(user)
    if Rails.env.production?
      "https://#{Rails.application.config.x.domains.community}/#{user.to_param}"
    else
      user_path(user)
    end
  end

  def community_user_path(user, params = {})
    base_path = if Rails.env.production? && request.host == Rails.application.config.x.domains.community
      "/#{user.to_param}"
    else
      user_path(user)
    end

    return base_path if params.blank?

    query = params.compact.to_query
    query.present? ? "#{base_path}?#{query}" : base_path
  end

  def community_map_data_url
    if Rails.env.production? && request.host == Rails.application.config.x.domains.community
      "/map_data"
    else
      community_map_data_path
    end
  end

  def main_site_url(path)
    if Rails.env.production? && request.host == Rails.application.config.x.domains.community
      "https://#{Rails.application.config.x.domains.primary}#{path}"
    else
      path
    end
  end

  def community_root_canonical_url
    if Rails.env.production?
      "https://#{Rails.application.config.x.domains.community}/"
    else
      users_url
    end
  end

  def community_user_canonical_url(user)
    if Rails.env.production?
      "https://#{Rails.application.config.x.domains.community}/#{user.to_param}"
    else
      user_url(user)
    end
  end
end
