module Post::MetadataFetchable
  extend ActiveSupport::Concern

  MAX_REDIRECTS = 3
  DEFAULT_TIMEOUT = 10
  DEFAULT_RETRIES = 1

  # Fetch OpenGraph metadata from url
  # Returns hash: { title:, description:, image_url:, parsed: }
  def fetch_metadata!(options = {})
    return {} if url.blank?

    connection_timeout = options[:connection_timeout] || DEFAULT_TIMEOUT
    read_timeout = options[:read_timeout] || DEFAULT_TIMEOUT
    retries = options[:retries] || DEFAULT_RETRIES

    html = fetch_html_with_retries(url, connection_timeout, read_timeout, retries)
    return {} unless html

    parsed = Nokogiri::HTML(html)

    {
      title: best_title(parsed),
      description: best_description(parsed),
      image_url: best_image(parsed),
      parsed: parsed
    }
  rescue => e
    Rails.logger.error "Failed to fetch metadata from #{url}: #{e.message}"
    {}
  end

  # Fetch page text content (for AI summarization of link posts)
  def fetch_external_content
    return nil if url.blank?

    html = fetch_html_with_retries(url, 5, 5, 1)
    return nil unless html

    parsed = Nokogiri::HTML(html)

    content_parts = []

    title_text = best_title(parsed)
    content_parts << "Title: #{title_text}" if title_text.present?

    desc_text = best_description(parsed)
    content_parts << "Description: #{desc_text}" if desc_text.present?

    main_content = extract_main_content(parsed)
    content_parts << main_content if main_content.present?

    if content_parts.length <= 2
      raw_text = parsed.css("body").text.squish rescue nil
      content_parts << raw_text if raw_text.present?
    end

    result = content_parts.join("\n\n")
    result.presence
  rescue => e
    Rails.logger.error "Failed to fetch external content from #{url}: #{e.message}"
    nil
  end

  private

  def fetch_html_with_retries(target_url, connection_timeout, read_timeout, retries)
    attempts = 0
    begin
      attempts += 1
      fetch_html(target_url, connection_timeout, read_timeout)
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT => e
      if attempts <= retries
        retry
      else
        Rails.logger.error "Failed to fetch #{target_url} after #{retries} retries: #{e.message}"
        nil
      end
    rescue => e
      Rails.logger.error "Error fetching #{target_url}: #{e.message}"
      nil
    end
  end

  def fetch_html(target_url, connection_timeout, read_timeout, redirect_count = 0)
    uri = URI(target_url)
    return nil unless %w[http https].include?(uri.scheme&.downcase)

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Ruby/#{RUBY_VERSION} (WhyRuby.info)"
    request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

    response = Net::HTTP.start(
      uri.hostname, uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: connection_timeout,
      read_timeout: read_timeout
    ) { |http| http.request(request) }

    case response
    when Net::HTTPSuccess
      response.body
    when Net::HTTPRedirection
      return nil if redirect_count >= MAX_REDIRECTS
      location = response["location"]
      return nil unless location
      redirect_uri = URI.join(uri.to_s, location)
      fetch_html(redirect_uri.to_s, connection_timeout, read_timeout, redirect_count + 1)
    else
      nil
    end
  end

  def best_title(parsed)
    extract_meta(parsed, property: "og:title") ||
      extract_meta(parsed, name: "twitter:title") ||
      parsed.at_css("title")&.text&.strip ||
      parsed.at_css("h1")&.text&.strip
  end

  def best_description(parsed)
    extract_meta(parsed, property: "og:description") ||
      extract_meta(parsed, name: "twitter:description") ||
      extract_meta(parsed, name: "description") ||
      extract_first_paragraph(parsed)
  end

  def best_image(parsed)
    og_image = extract_meta(parsed, property: "og:image")
    return resolve_metadata_url(og_image) if og_image

    twitter_image = extract_meta(parsed, name: "twitter:image")
    return resolve_metadata_url(twitter_image) if twitter_image

    largest = find_largest_image(parsed)
    return resolve_metadata_url(largest) if largest

    first_image = parsed.at_css("img")&.[]("src")
    resolve_metadata_url(first_image) if first_image
  end

  def extract_meta(parsed, property: nil, name: nil)
    if property
      parsed.at_css("meta[property='#{property}']")&.[]("content")&.strip
    elsif name
      parsed.at_css("meta[name='#{name}']")&.[]("content")&.strip
    end
  end

  def extract_first_paragraph(parsed)
    parsed.css("p").each do |p|
      text = p.text.strip
      return text if text.length > 50
    end
    nil
  end

  def extract_main_content(parsed)
    %w[main article [role="main"] .content #content .post-content .entry-content .article-body].each do |selector|
      element = parsed.at_css(selector)
      if element
        text = element.text.squish
        return text if text.length > 100
      end
    end

    paragraphs = parsed.css("p").map(&:text).reject(&:blank?)
    paragraphs.join(" ").presence
  end

  def find_largest_image(parsed)
    largest = nil
    max_size = 0

    parsed.css("img").each do |img|
      width = img["width"].to_i
      height = img["height"].to_i
      next if width.zero? || height.zero? || width < 200 || height < 200

      aspect_ratio = width.to_f / height
      next if aspect_ratio < 0.33 || aspect_ratio > 3.0

      size = width * height
      if size > max_size
        max_size = size
        largest = img["src"]
      end
    end

    largest
  end

  def resolve_metadata_url(path)
    return nil if path.blank?
    return path if path.start_with?("http://", "https://")

    begin
      URI.join(url, path).to_s
    rescue => e
      Rails.logger.warn "Failed to resolve relative URL #{path}: #{e.message}"
      path
    end
  end
end
