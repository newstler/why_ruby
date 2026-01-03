class MetadataFetcher
  require "net/http"
  require "nokogiri"

  MAX_REDIRECTS = 3
  DEFAULT_TIMEOUT = 10
  DEFAULT_RETRIES = 1

  attr_reader :url, :options, :parsed

  def initialize(url, options = {})
    @url = url
    @options = options
    @connection_timeout = options[:connection_timeout] || DEFAULT_TIMEOUT
    @read_timeout = options[:read_timeout] || DEFAULT_TIMEOUT
    @retries = options[:retries] || DEFAULT_RETRIES
    @allow_redirections = options[:allow_redirections]
    @parsed = nil
  end

  def fetch!
    html = fetch_html_with_retries
    return {} unless html

    @parsed = Nokogiri::HTML(html)

    {
      title: best_title,
      description: best_description,
      image_url: best_image,
      parsed: @parsed
    }
  rescue => e
    Rails.logger.error "Failed to fetch metadata from #{@url}: #{e.message}"
    {}
  end

  def best_title
    extract_meta(property: "og:title") ||
      extract_meta(name: "twitter:title") ||
      @parsed&.at_css("title")&.text&.strip ||
      @parsed&.at_css("h1")&.text&.strip
  end

  def best_description
    extract_meta(property: "og:description") ||
      extract_meta(name: "twitter:description") ||
      extract_meta(name: "description") ||
      extract_first_paragraph
  end

  def best_image
    og_image = extract_meta(property: "og:image")
    return resolve_url(og_image) if og_image

    twitter_image = extract_meta(name: "twitter:image")
    return resolve_url(twitter_image) if twitter_image

    largest_image = find_largest_image
    return resolve_url(largest_image) if largest_image

    first_image = @parsed&.at_css("img")&.[]("src")
    resolve_url(first_image) if first_image
  end

  private

  def fetch_html_with_retries
    attempts = 0
    begin
      attempts += 1
      fetch_html(@url)
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ETIMEDOUT => e
      if attempts <= @retries
        Rails.logger.warn "Timeout fetching #{@url}, retrying (#{attempts}/#{@retries}): #{e.message}"
        retry
      else
        Rails.logger.error "Failed to fetch #{@url} after #{@retries} retries: #{e.message}"
        nil
      end
    rescue => e
      Rails.logger.error "Error fetching #{@url}: #{e.message}"
      nil
    end
  end

  def fetch_html(url, redirect_count = 0)
    uri = URI(url)

    # Validate URL scheme
    unless %w[http https].include?(uri.scheme&.downcase)
      Rails.logger.error "Invalid URL scheme: #{uri.scheme}"
      return nil
    end

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "Ruby/#{RUBY_VERSION} (WhyRuby.info)"
    request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

    response = Net::HTTP.start(
      uri.hostname,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: @connection_timeout,
      read_timeout: @read_timeout
    ) do |http|
      http.request(request)
    end

    case response
    when Net::HTTPSuccess
      response.body
    when Net::HTTPRedirection
      handle_redirect(response, uri, redirect_count)
    else
      Rails.logger.error "HTTP error fetching #{url}: #{response.code} - #{response.message}"
      nil
    end
  end

  def handle_redirect(response, current_uri, redirect_count)
    if redirect_count >= MAX_REDIRECTS
      Rails.logger.error "Too many redirects (#{redirect_count}) for #{@url}"
      return nil
    end

    location = response["location"]
    return nil unless location

    # Resolve relative redirects
    redirect_uri = URI.join(current_uri.to_s, location)

    # Check if redirect is safe
    if @allow_redirections == :safe && !safe_redirect?(current_uri, redirect_uri)
      Rails.logger.error "Unsafe redirect from #{current_uri} to #{redirect_uri}"
      return nil
    end

    fetch_html(redirect_uri.to_s, redirect_count + 1)
  end

  def safe_redirect?(current_uri, redirect_uri)
    # Only allow HTTPS redirects or same-origin HTTP
    redirect_uri.scheme == "https" ||
      (redirect_uri.scheme == "http" && redirect_uri.host == current_uri.host)
  end

  def extract_meta(property: nil, name: nil)
    if property
      @parsed&.at_css("meta[property='#{property}']")&.[]("content")&.strip
    elsif name
      @parsed&.at_css("meta[name='#{name}']")&.[]("content")&.strip
    end
  end

  def extract_first_paragraph
    paragraphs = @parsed&.css("p")
    return nil unless paragraphs

    paragraphs.each do |p|
      text = p.text.strip
      # Return first paragraph with substantial content
      return text if text.length > 50
    end

    nil
  end

  def find_largest_image
    images = @parsed&.css("img")
    return nil unless images&.any?

    largest = nil
    max_size = 0

    images.each do |img|
      width = img["width"].to_i
      height = img["height"].to_i

      # Skip if dimensions not specified
      next if width.zero? || height.zero?

      # Skip tiny images (likely icons/logos)
      next if width < 200 || height < 200

      # Skip images with weird aspect ratios
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

  def resolve_url(path)
    return nil if path.blank?
    return path if path.start_with?("http://", "https://")

    # Resolve relative URLs
    begin
      base_uri = URI(@url)
      URI.join(base_uri, path).to_s
    rescue => e
      Rails.logger.warn "Failed to resolve relative URL #{path}: #{e.message}"
      path
    end
  end
end
