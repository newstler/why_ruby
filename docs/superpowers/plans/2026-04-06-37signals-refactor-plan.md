# 37signals Style Refactor + RubyLLM Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate all service objects (moving logic to model concerns), migrate AI jobs from raw OpenAI/Anthropic to RubyLLM with per-user cost tracking, and update AGENTS.md.

**Architecture:** Services become model concerns (adjective-named). AI operations create system Chat/Message records via RubyLLM's `acts_as_chat` for automatic token/cost tracking. Jobs become thin delegators to model methods.

**Tech Stack:** Rails 8.2, RubyLLM (~> 1.9), SQLite, Minitest, WebMock

---

## Task 1: User::Geocodable — LocationNormalizer + TimezoneResolver → concern

**Files:**
- Create: `app/models/concerns/user/geocodable.rb`
- Modify: `app/models/user.rb`
- Modify: `app/jobs/normalize_location_job.rb`
- Modify: `test/jobs/normalize_location_job_test.rb`
- Move: `test/services/location_normalizer_test.rb` → `test/models/concerns/user/geocodable_test.rb`
- Move: `test/services/timezone_resolver_test.rb` → merged into above
- Delete: `app/services/location_normalizer.rb`
- Delete: `app/services/timezone_resolver.rb`

- [ ] **Step 1: Create the concern**

```ruby
# app/models/concerns/user/geocodable.rb
# frozen_string_literal: true

require "net/http"
require "json"

module User::Geocodable
  extend ActiveSupport::Concern

  PHOTON_API = "https://photon.komoot.io/api/"

  # Legacy IANA identifiers renamed in recent tzdata releases.
  LEGACY_TIMEZONES = {
    "Europe/Kiev" => "Europe/Kyiv"
  }.freeze

  GeoResult = Data.define(:city, :state, :country_code, :latitude, :longitude)

  # Geocode user location string, setting lat/lng/normalized_location/timezone
  def geocode!
    result = photon_search(location)

    unless result
      update_columns(normalized_location: nil, latitude: nil, longitude: nil, timezone: nil)
      return
    end

    normalized_string = build_normalized_string(result)

    unless normalized_string
      update_columns(normalized_location: nil, latitude: nil, longitude: nil, timezone: nil)
      return
    end

    timezone = resolve_timezone(result.latitude, result.longitude)

    update_columns(
      normalized_location: normalized_string,
      latitude: result.latitude,
      longitude: result.longitude,
      timezone: timezone
    )
  end

  private

  def photon_search(query)
    return nil if query.blank?

    # Skip strings that are clearly not geographic (pure emoji, etc.)
    stripped = query.gsub(/[\p{Emoji_Presentation}\p{Extended_Pictographic}]/, "").strip
    return nil if stripped.empty?

    uri = URI(PHOTON_API)
    uri.query = URI.encode_www_form(q: query, limit: 1)

    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    feature = data.dig("features", 0)
    return nil unless feature

    properties = feature["properties"]
    return nil unless properties

    coordinates = feature.dig("geometry", "coordinates")
    lon, lat = coordinates if coordinates.is_a?(Array) && coordinates.size >= 2

    GeoResult.new(
      city: properties["city"] || (properties["type"] == "city" ? properties["name"] : nil),
      state: properties["state"],
      country_code: properties["countrycode"],
      latitude: lat&.to_f,
      longitude: lon&.to_f
    )
  rescue StandardError => e
    Rails.logger.warn "Photon geocoding failed: #{e.message}"
    nil
  end

  def build_normalized_string(result)
    country_code = result.country_code&.upcase
    return nil unless country_code.present?

    if result.city.present?
      "#{result.city}, #{country_code}"
    elsif result.state.present?
      "#{result.state}, #{country_code}"
    else
      country_code
    end
  end

  def resolve_timezone(latitude, longitude)
    return "Etc/UTC" if latitude.nil? || longitude.nil?

    result = WhereTZ.lookup(latitude, longitude)
    timezone = result.is_a?(Array) ? result.first : result
    normalize_timezone(timezone)
  rescue StandardError => e
    Rails.logger.warn "Timezone lookup failed for (#{latitude}, #{longitude}): #{e.message}"
    "Etc/UTC"
  end

  def normalize_timezone(timezone)
    return "Etc/UTC" if timezone.blank?

    normalized = LEGACY_TIMEZONES[timezone] || timezone
    TZInfo::Timezone.get(normalized)
    normalized
  rescue TZInfo::InvalidTimezoneIdentifier
    Rails.logger.warn "Unknown timezone identifier: #{timezone}, falling back to Etc/UTC"
    "Etc/UTC"
  end
end
```

- [ ] **Step 2: Include concern in User model**

In `app/models/user.rb`, add after the `Costable` include:

```ruby
include User::Geocodable
```

- [ ] **Step 3: Thin out the job**

Replace `app/jobs/normalize_location_job.rb`:

```ruby
# frozen_string_literal: true

class NormalizeLocationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    user&.geocode!
  end
end
```

- [ ] **Step 4: Move and merge tests**

Create `test/models/concerns/user/geocodable_test.rb` combining both service tests:

```ruby
# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class User::GeocodableTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
    @user = users(:user_with_testimonial)
  end

  teardown do
    WebMock.allow_net_connect!
  end

  # --- Geocoding ---

  test "geocode! sets normalized_location, coordinates, and timezone" do
    @user.update_columns(location: "NYC")
    stub_photon("NYC", city: "New York", countrycode: "us", lon: -74.006, lat: 40.7128)

    @user.geocode!
    @user.reload

    assert_equal "New York, US", @user.normalized_location
    assert_in_delta 40.7128, @user.latitude, 0.001
    assert_in_delta(-74.006, @user.longitude, 0.001)
    assert_equal "America/New_York", @user.timezone
  end

  test "geocode! clears fields when geocoding fails" do
    @user.update_columns(location: "Universe", normalized_location: "Old, US", latitude: 1.0, longitude: 1.0, timezone: "America/New_York")
    stub_photon_empty("Universe")

    @user.geocode!
    @user.reload

    assert_nil @user.normalized_location
    assert_nil @user.latitude
    assert_nil @user.longitude
    assert_nil @user.timezone
  end

  test "geocode! returns nil for blank location" do
    @user.update_columns(location: nil)

    @user.geocode!
    @user.reload

    assert_nil @user.normalized_location
  end

  test "geocode! returns nil for pure emoji location" do
    @user.update_columns(location: "\u{1F30D}")

    @user.geocode!
    @user.reload

    assert_nil @user.normalized_location
  end

  test "geocode! returns State, CC when no city available" do
    @user.update_columns(location: "California")
    stub_photon("California", city: nil, countrycode: "us", state: "California", lon: -119.417, lat: 36.778)

    @user.geocode!
    @user.reload

    assert_equal "California, US", @user.normalized_location
  end

  test "geocode! returns just CC when only country code available" do
    @user.update_columns(location: "Germany")
    stub_photon("Germany", city: nil, countrycode: "de", state: nil, lon: 10.451, lat: 51.165)

    @user.geocode!
    @user.reload

    assert_equal "DE", @user.normalized_location
  end

  test "geocode! clears fields when result has no country code" do
    @user.update_columns(location: "Somewhere")
    stub_photon("Somewhere", city: "Somewhere", countrycode: nil, state: nil, lon: 0.0, lat: 0.0)

    @user.geocode!
    @user.reload

    assert_nil @user.normalized_location
  end

  # --- Timezone ---

  test "geocode! resolves Berlin coordinates to Europe/Berlin" do
    @user.update_columns(location: "Berlin")
    stub_photon("Berlin", city: "Berlin", countrycode: "de", lon: 13.405, lat: 52.52)

    @user.geocode!
    @user.reload

    assert_equal "Europe/Berlin", @user.timezone
  end

  test "geocode! resolves Kyiv coordinates to canonical Europe/Kyiv" do
    @user.update_columns(location: "Kyiv")
    stub_photon("Kyiv", city: "Kyiv", countrycode: "ua", lon: 30.52, lat: 50.45)

    @user.geocode!
    @user.reload

    assert_equal "Europe/Kyiv", @user.timezone
  end

  private

  def stub_photon(query, city:, countrycode:, state: nil, lon: 0.0, lat: 0.0)
    response = {
      type: "FeatureCollection",
      features: [ {
        type: "Feature",
        geometry: { type: "Point", coordinates: [ lon, lat ] },
        properties: { city: city, countrycode: countrycode, state: state }
      } ]
    }

    stub_request(:get, "https://photon.komoot.io/api/")
      .with(query: { q: query, limit: "1" })
      .to_return(status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_photon_empty(query)
    response = { type: "FeatureCollection", features: [] }

    stub_request(:get, "https://photon.komoot.io/api/")
      .with(query: { q: query, limit: "1" })
      .to_return(status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" })
  end
end
```

- [ ] **Step 5: Update NormalizeLocationJob test**

Replace `test/jobs/normalize_location_job_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class NormalizeLocationJobTest < ActiveJob::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  teardown do
    WebMock.allow_net_connect!
  end

  test "delegates to user.geocode!" do
    user = users(:user_with_testimonial)
    user.update_columns(location: "NYC")

    stub_photon("NYC", city: "New York", countrycode: "us", lon: -74.006, lat: 40.7128)

    NormalizeLocationJob.perform_now(user.id)

    user.reload
    assert_equal "New York, US", user.normalized_location
  end

  test "handles non-existent user gracefully" do
    assert_nothing_raised do
      NormalizeLocationJob.perform_now("nonexistent-id")
    end
  end

  private

  def stub_photon(query, city:, countrycode:, lon: 0.0, lat: 0.0)
    response = {
      type: "FeatureCollection",
      features: [ {
        type: "Feature",
        geometry: { type: "Point", coordinates: [ lon, lat ] },
        properties: { city: city, countrycode: countrycode }
      } ]
    }

    stub_request(:get, "https://photon.komoot.io/api/")
      .with(query: { q: query, limit: "1" })
      .to_return(status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" })
  end
end
```

- [ ] **Step 6: Delete old service files and tests**

```bash
rm app/services/location_normalizer.rb
rm app/services/timezone_resolver.rb
rm test/services/location_normalizer_test.rb
rm test/services/timezone_resolver_test.rb
```

- [ ] **Step 7: Run tests**

Run: `rails test test/models/concerns/user/geocodable_test.rb test/jobs/normalize_location_job_test.rb`
Expected: All pass

- [ ] **Step 8: Run full test suite**

Run: `rails test`
Expected: All pass

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor: move LocationNormalizer + TimezoneResolver to User::Geocodable concern"
```

---

## Task 2: Post::SvgSanitizable — SvgSanitizer → concern

**Files:**
- Create: `app/models/concerns/post/svg_sanitizable.rb`
- Modify: `app/models/post.rb`
- Delete: `app/services/svg_sanitizer.rb`

- [ ] **Step 1: Create the concern**

```ruby
# app/models/concerns/post/svg_sanitizable.rb
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
```

- [ ] **Step 2: Include concern in Post model and update callback**

In `app/models/post.rb`, add near the top:

```ruby
include Post::SvgSanitizable
```

Change the `clean_logo_svg` private method from:

```ruby
def clean_logo_svg
  return unless logo_svg.present?
  self.logo_svg = SvgSanitizer.sanitize(logo_svg)
end
```

to:

```ruby
def clean_logo_svg
  sanitize_logo_svg!
end
```

- [ ] **Step 3: Delete old service**

```bash
rm app/services/svg_sanitizer.rb
```

- [ ] **Step 4: Run tests**

Run: `rails test`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: move SvgSanitizer to Post::SvgSanitizable concern"
```

---

## Task 3: Post::MetadataFetchable — MetadataFetcher → concern

**Files:**
- Create: `app/models/concerns/post/metadata_fetchable.rb`
- Modify: `app/models/post.rb`
- Modify: `app/controllers/posts_controller.rb`
- Delete: `app/services/metadata_fetcher.rb`

- [ ] **Step 1: Create the concern**

```ruby
# app/models/concerns/post/metadata_fetchable.rb
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
    allow_redirections = options[:allow_redirections]

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
```

- [ ] **Step 2: Include concern in Post and update controller**

In `app/models/post.rb`, add:

```ruby
include Post::MetadataFetchable
```

In `app/controllers/posts_controller.rb`, change the `fetch_metadata` action from:

```ruby
fetcher = MetadataFetcher.new(url)
result = fetcher.fetch!

metadata = {
  title: result[:title],
  summary: result[:description],
  image_url: result[:image_url]
}
```

to:

```ruby
post = Post.new(url: url)
result = post.fetch_metadata!

metadata = {
  title: result[:title],
  summary: result[:description],
  image_url: result[:image_url]
}
```

- [ ] **Step 3: Delete old service**

```bash
rm app/services/metadata_fetcher.rb
```

- [ ] **Step 4: Run tests**

Run: `rails test`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: move MetadataFetcher to Post::MetadataFetchable concern"
```

---

## Task 4: Post::ImageVariantable — ImageProcessor → concern

**Files:**
- Create: `app/models/concerns/post/image_variantable.rb`
- Modify: `app/models/post.rb`
- Modify: `app/controllers/posts_controller.rb`
- Delete: `app/services/image_processor.rb`

- [ ] **Step 1: Create the concern**

```ruby
# app/models/concerns/post/image_variantable.rb
module Post::ImageVariantable
  extend ActiveSupport::Concern

  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg image/jpg image/png image/webp image/tiff image/x-tiff
  ].freeze

  IMAGE_VARIANTS = {
    tile: { width: 684, height: 384, quality: 92 },
    post: { width: 1664, height: 936, quality: 94 },
    og: { width: 1200, height: 630, quality: 95 }
  }.freeze

  MAX_IMAGE_SIZE = 20.megabytes

  # Generate all WebP variants from featured_image
  def process_image_variants!
    return { error: "No image attached" } unless featured_image.attached?
    return { error: "File too large" } if featured_image.blob.byte_size > MAX_IMAGE_SIZE
    return { error: "Invalid file type" } unless ALLOWED_CONTENT_TYPES.include?(featured_image.blob.content_type)

    variants = {}

    featured_image.blob.open do |tempfile|
      IMAGE_VARIANTS.each do |name, config|
        variant_blob = generate_image_variant(tempfile.path, config)
        variants[name] = variant_blob.id if variant_blob
      end
    end

    update_columns(image_variants: variants)
    { success: true, variants: variants }
  rescue => e
    Rails.logger.error "Image processing error: #{e.message}"
    { error: "Processing failed: #{e.message}" }
  end

  def image_variant(size = :medium)
    return nil unless featured_image.attached? && image_variants.present?

    variant_id = image_variants[size.to_s]
    return featured_image.blob unless variant_id

    ActiveStorage::Blob.find_by(id: variant_id) || featured_image.blob
  end

  def image_url_for_size(size = :medium)
    blob = image_variant(size)
    return nil unless blob

    Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
  end

  def has_processed_images?
    image_variants.present?
  end

  def reprocess_image!
    return unless featured_image.attached?

    process_image_variants!
  end

  def clear_image_variants!
    if image_variants.present?
      image_variants.each do |_size, blob_id|
        ActiveStorage::Blob.find_by(id: blob_id)&.purge_later
      end
    end

    update_columns(image_variants: nil)
  end

  # Attach image from URL and process variants
  def attach_image_from_url!(image_url)
    return if image_url.blank?

    require "open-uri"

    image_io = URI.open(image_url,
      "User-Agent" => "Ruby/#{RUBY_VERSION}",
      read_timeout: 10,
      open_timeout: 10
    )

    return if image_io.size > MAX_IMAGE_SIZE

    temp_file = Tempfile.new([ "remote_image", File.extname(URI.parse(image_url).path) ])
    temp_file.binmode
    temp_file.write(image_io.read)
    temp_file.rewind

    featured_image.attach(io: temp_file, filename: File.basename(URI.parse(image_url).path))
    process_image_variants!
  rescue => e
    Rails.logger.error "Failed to fetch/process image from URL #{image_url}: #{e.message}"
  ensure
    temp_file&.close
    temp_file&.unlink
  end

  private

  def generate_image_variant(source_path, config)
    variant_file = Tempfile.new([ "variant", ".webp" ])

    begin
      cmd = [
        "convert", source_path,
        "-resize", "#{config[:width]}x#{config[:height]}>",
        "-filter", "Lanczos",
        "-quality", config[:quality].to_s,
        "-define", "webp:lossless=false",
        "-define", "webp:method=6",
        "-define", "webp:alpha-quality=100",
        "-define", "webp:image-hint=photo",
        "-strip",
        "webp:#{variant_file.path}"
      ]

      unless system(*cmd, err: File::NULL)
        Rails.logger.error "Failed to generate variant: #{config.inspect}"
        return nil
      end

      ActiveStorage::Blob.create_and_upload!(
        io: File.open(variant_file.path),
        filename: "variant_#{config[:width]}x#{config[:height]}.webp",
        content_type: "image/webp"
      )
    ensure
      variant_file.close
      variant_file.unlink
    end
  end

  def process_featured_image_if_needed
    return unless featured_image.attached?

    should_process = !has_processed_images? ||
                    (previous_changes.key?("updated_at") && featured_image.blob.created_at > 1.minute.ago)

    return unless should_process

    Rails.logger.info "Processing image for Post ##{id}"
    result = process_image_variants!

    if result[:success]
      Rails.logger.info "Successfully processed image for Post ##{id}"
    else
      Rails.logger.error "Failed to process image for Post ##{id}: #{result[:error]}"
    end
  end

  def featured_image_validation
    return unless featured_image.attached?

    if featured_image.blob.byte_size > MAX_IMAGE_SIZE
      errors.add(:featured_image, "is too large (maximum is #{MAX_IMAGE_SIZE / 1.megabyte}MB)")
    end

    unless ALLOWED_CONTENT_TYPES.include?(featured_image.blob.content_type)
      errors.add(:featured_image, "must be a JPEG, PNG, WebP, or TIFF image")
    end
  end
end
```

- [ ] **Step 2: Include concern in Post, remove duplicated methods and old references**

In `app/models/post.rb`:
- Add `include Post::ImageVariantable`
- Remove the `MAX_IMAGE_SIZE` constant (now in concern)
- Remove the `image_variant`, `image_url_for_size`, `has_processed_images?`, `reprocess_image!`, `clear_image_variants!` methods (now in concern)
- Remove the `process_featured_image_if_needed` and `featured_image_validation` private methods (now in concern)
- The `after_commit :process_featured_image_if_needed` and `validate :featured_image_validation` callbacks remain — they now delegate to the concern

- [ ] **Step 3: Update controller**

In `app/controllers/posts_controller.rb`, change `fetch_and_attach_image_from_url`:

```ruby
def fetch_and_attach_image_from_url(url)
  return if url.blank?
  @post.attach_image_from_url!(url)
end
```

- [ ] **Step 4: Delete old service**

```bash
rm app/services/image_processor.rb
```

- [ ] **Step 5: Run tests**

Run: `rails test`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: move ImageProcessor to Post::ImageVariantable concern"
```

---

## Task 5: Post::OgImageGeneratable — SuccessStoryImageGenerator → concern

**Files:**
- Create: `app/models/concerns/post/og_image_generatable.rb`
- Modify: `app/models/post.rb`
- Modify: `app/jobs/generate_success_story_image_job.rb`
- Delete: `app/services/success_story_image_generator.rb`

- [ ] **Step 1: Create the concern**

```ruby
# app/models/concerns/post/og_image_generatable.rb
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
```

- [ ] **Step 2: Include concern in Post, update callback and job**

In `app/models/post.rb`:
- Add `include Post::OgImageGeneratable`
- Remove the private `generate_success_story_image` method
- Change the `after_save` callback from:

```ruby
after_save :generate_success_story_image, if: -> { success_story? && saved_change_to_logo_svg? }
```

to:

```ruby
after_save :enqueue_og_image_generation, if: -> { success_story? && saved_change_to_logo_svg? }
```

Add private method:

```ruby
def enqueue_og_image_generation
  force = saved_change_to_logo_svg? && !saved_change_to_id?
  GenerateSuccessStoryImageJob.perform_later(self, force: force)
end
```

Replace `app/jobs/generate_success_story_image_job.rb`:

```ruby
class GenerateSuccessStoryImageJob < ApplicationJob
  queue_as :default

  def perform(post, force: false)
    post.generate_og_image!(force: force)
  rescue => e
    Rails.logger.error "Failed to generate success story image for post #{post.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
```

- [ ] **Step 3: Delete old service**

```bash
rm app/services/success_story_image_generator.rb
```

- [ ] **Step 4: Run tests**

Run: `rails test`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: move SuccessStoryImageGenerator to Post::OgImageGeneratable concern"
```

---

## Task 6: User::GithubSyncable — GithubDataFetcher → concern

**Files:**
- Create: `app/models/concerns/user/github_syncable.rb`
- Modify: `app/models/user.rb`
- Modify: `app/jobs/update_github_data_job.rb`
- Delete: `app/services/github_data_fetcher.rb`

- [ ] **Step 1: Create the concern**

Move the full content of `GithubDataFetcher` into a concern. The class methods become `class_methods do` block, instance methods become regular concern methods:

```ruby
# app/models/concerns/user/github_syncable.rb
require "net/http"
require "json"

module User::GithubSyncable
  extend ActiveSupport::Concern

  GITHUB_GRAPHQL_ENDPOINT = "https://api.github.com/graphql"

  # Sync from OAuth callback data
  def sync_github_data_from_oauth!(auth_data)
    api_token = auth_data.credentials.token

    if auth_data.extra&.raw_info
      raw_info = auth_data.extra.raw_info
      update!(
        username: auth_data.info.nickname,
        email: auth_data.info.email,
        name: raw_info.name || name,
        bio: raw_info.bio || bio,
        company: raw_info.company,
        website: raw_info.blog.presence || website,
        twitter: raw_info.twitter_username.presence || twitter,
        location: raw_info.location,
        avatar_url: auth_data.info.image
      )
    end

    github_username = auth_data.info.nickname || username
    return unless github_username.present?

    repos = fetch_ruby_repositories(github_username, api_token)
    if repos.present?
      repos.each { |r| r[:github_url] ||= r.delete(:url) }
      self.class.sync_projects!(self, repos)
    end

    update!(github_data_updated_at: Time.current)
  rescue => e
    Rails.logger.error "Failed to sync GitHub data for #{username}: #{e.message}"
  end

  class_methods do
    # Batch GraphQL fetch for multiple users
    def batch_sync_github_data!(users, api_token: nil)
      api_token ||= Rails.application.credentials.dig(:github, :api_token)
      return { updated: 0, failed: users.size, errors: [ "No API token configured" ] } unless api_token.present?

      users_with_usernames = users.select { |u| u.username.present? }
      return { updated: 0, failed: 0, errors: [] } if users_with_usernames.empty?

      query = build_batch_query(users_with_usernames)
      response = github_graphql_request(query, api_token, retries: 2)

      if response[:errors].present? && response[:data].nil?
        error_msg = response[:errors].first.to_s
        if error_msg.match?(/50[234]/) && users_with_usernames.size > 1
          Rails.logger.warn "Batch of #{users_with_usernames.size} failed with #{error_msg}, splitting in half..."
          mid = users_with_usernames.size / 2
          first_half = batch_sync_github_data!(users_with_usernames[0...mid], api_token: api_token)
          sleep(1)
          second_half = batch_sync_github_data!(users_with_usernames[mid..], api_token: api_token)

          return {
            updated: first_half[:updated] + second_half[:updated],
            failed: first_half[:failed] + second_half[:failed],
            errors: first_half[:errors] + second_half[:errors]
          }
        end

        return { updated: 0, failed: users_with_usernames.size, errors: response[:errors] }
      end

      updated = 0
      failed = 0
      errors = []

      users_with_usernames.each_with_index do |user, index|
        user_data = response.dig(:data, :"user_#{index}")
        repos_data = response.dig(:data, :"repos_#{index}", :nodes)

        if user_data.nil?
          failed += 1
          errors << "User #{user.username} not found on GitHub"
          next
        end

        begin
          update_user_from_graphql(user, user_data, repos_data || [])
          updated += 1
        rescue => e
          failed += 1
          errors << "Failed to update #{user.username}: #{e.message}"
          Rails.logger.error "GraphQL batch update error for #{user.username}: #{e.message}"
        end
      end

      { updated: updated, failed: failed, errors: errors }
    end

    def sync_projects!(user, repos_data, force_snapshot: false)
      current_urls = repos_data.map { |r| r[:github_url] || r[:url] }
      user.projects.active.where.not(github_url: current_urls).update_all(archived: true)

      repos_data.each do |repo_data|
        url = repo_data[:github_url] || repo_data[:url]
        project = user.projects.find_or_initialize_by(github_url: url)

        project.assign_attributes(
          name: repo_data[:name],
          description: repo_data[:description],
          stars: repo_data[:stars].to_i,
          forks_count: repo_data[:forks_count].to_i,
          size: repo_data[:size].to_i,
          topics: repo_data[:topics] || [],
          pushed_at: repo_data[:pushed_at].present? ? Time.parse(repo_data[:pushed_at].to_s) : nil,
          archived: false
        )

        project.save!
        project.record_snapshot!(force: force_snapshot)
      end

      visible = user.projects.visible
      gained = visible.sum { |p| p.stars_gained }
      user.update!(
        github_repos_count: visible.count,
        github_stars_sum: visible.sum(:stars),
        stars_gained: gained
      )
    end

    private

    def github_graphql_request(query, api_token, retries: 3)
      uri = URI(GITHUB_GRAPHQL_ENDPOINT)

      retries.times do |attempt|
        begin
          request = Net::HTTP::Post.new(uri)
          request["Content-Type"] = "application/json"
          request["Authorization"] = "Bearer #{api_token}"
          request.body = { query: query }.to_json

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

          if response.code == "200"
            return JSON.parse(response.body, symbolize_names: true)
          elsif %w[502 503 504].include?(response.code) && attempt < retries - 1
            sleep(2 ** (attempt + 1))
            next
          else
            return { errors: [ "HTTP #{response.code}: #{response.message}" ] }
          end
        rescue Net::OpenTimeout, Net::ReadTimeout => e
          if attempt < retries - 1
            sleep(2 ** (attempt + 1))
            next
          else
            return { errors: [ "Request timed out: #{e.message}" ] }
          end
        end
      end
    end

    def build_batch_query(users)
      user_queries = users.each_with_index.map do |user, index|
        <<~GRAPHQL
          user_#{index}: user(login: "#{user.username}") {
            login
            email
            name
            bio
            company
            websiteUrl
            twitterUsername
            location
            avatarUrl
          }
          repos_#{index}: search(query: "user:#{user.username} language:Ruby fork:false archived:false sort:updated", type: REPOSITORY, first: 100) {
            nodes {
              ... on Repository {
                name
                description
                stargazerCount
                url
                forks {
                  totalCount
                }
                diskUsage
                pushedAt
                repositoryTopics(first: 10) {
                  nodes {
                    topic {
                      name
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end.join("\n")

      "query { #{user_queries} }"
    end

    def update_user_from_graphql(user, profile_data, repos_data)
      user.update!(
        username: profile_data[:login],
        email: profile_data[:email] || user.email,
        name: profile_data[:name] || user.name,
        bio: profile_data[:bio] || user.bio,
        company: profile_data[:company],
        website: profile_data[:websiteUrl].presence || user.website,
        twitter: profile_data[:twitterUsername].presence || user.twitter,
        location: profile_data[:location],
        avatar_url: profile_data[:avatarUrl],
        github_data_updated_at: Time.current
      )

      repos = repos_data.map do |repo|
        {
          name: repo[:name],
          description: repo[:description],
          stars: repo[:stargazerCount],
          github_url: repo[:url],
          forks_count: repo.dig(:forks, :totalCount) || 0,
          size: repo[:diskUsage] || 0,
          topics: (repo.dig(:repositoryTopics, :nodes) || []).map { |t| t.dig(:topic, :name) }.compact,
          pushed_at: repo[:pushedAt]
        }
      end

      sync_projects!(user, repos, force_snapshot: true)
    end
  end

  private

  def fetch_ruby_repositories(github_username, api_token)
    uri = URI("https://api.github.com/users/#{github_username}/repos?per_page=100&sort=pushed")
    request = Net::HTTP::Get.new(uri)
    request["Accept"] = "application/vnd.github.v3+json"
    request["Authorization"] = "Bearer #{api_token}" if api_token.present?

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

    if response.code == "200"
      repos = JSON.parse(response.body)

      repos.select do |repo|
        next if repo["fork"]
        repo["language"] == "Ruby" ||
        repo["description"]&.downcase&.include?("ruby") ||
        repo["name"]&.downcase&.include?("ruby") ||
        repo["name"]&.downcase&.include?("rails")
      end.map do |repo|
        {
          name: repo["name"],
          description: repo["description"],
          stars: repo["stargazers_count"],
          url: repo["html_url"],
          forks_count: repo["forks_count"],
          size: repo["size"],
          topics: repo["topics"] || [],
          pushed_at: repo["pushed_at"]
        }
      end.sort_by { |r| -r[:stars] }
    else
      Rails.logger.error "GitHub API returned #{response.code} for #{github_username}: #{response.body}"
      []
    end
  end
end
```

- [ ] **Step 2: Include concern in User, update from_omniauth**

In `app/models/user.rb`:
- Add `include User::GithubSyncable`
- Change `from_omniauth` from:

```ruby
def self.from_omniauth(auth)
  user = where(github_id: auth.uid).first_or_create do |user|
    user.email = auth.info.email
    user.username = auth.info.nickname
    user.avatar_url = auth.info.image
  end
  GithubDataFetcher.new(user, auth).fetch_and_update!
  user
end
```

to:

```ruby
def self.from_omniauth(auth)
  user = where(github_id: auth.uid).first_or_create do |user|
    user.email = auth.info.email
    user.username = auth.info.nickname
    user.avatar_url = auth.info.image
  end
  user.sync_github_data_from_oauth!(auth)
  user
end
```

- [ ] **Step 3: Thin out UpdateGithubDataJob**

Replace `app/jobs/update_github_data_job.rb`:

```ruby
class UpdateGithubDataJob < ApplicationJob
  queue_as :default

  BATCH_SIZE = 5

  def perform
    Rails.logger.info "Starting GitHub data update using GraphQL batch fetching..."

    total_updated = 0
    total_failed = 0
    all_errors = []

    User.where.not(username: [ nil, "" ]).find_in_batches(batch_size: BATCH_SIZE) do |batch|
      results = User.batch_sync_github_data!(batch)

      total_updated += results[:updated]
      total_failed += results[:failed]
      all_errors.concat(results[:errors]) if results[:errors].present?

      sleep 0.5
    end

    Rails.logger.info "GitHub data update completed. Updated: #{total_updated}, Failed: #{total_failed}"

    if all_errors.any?
      Rails.logger.warn "Errors encountered: #{all_errors.first(10).join(', ')}#{all_errors.size > 10 ? '...' : ''}"
    end
  end
end
```

- [ ] **Step 4: Delete old service**

```bash
rm app/services/github_data_fetcher.rb
```

- [ ] **Step 5: Run tests**

Run: `rails test`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: move GithubDataFetcher to User::GithubSyncable concern"
```

---

## Task 7: Delete app/services/ directory

- [ ] **Step 1: Verify directory is empty and delete**

```bash
ls app/services/
rmdir app/services/
rm -rf test/services/
```

- [ ] **Step 2: Run tests**

Run: `rails test`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove empty app/services/ directory"
```

---

## Task 8: Add purpose column to chats

**Files:**
- Create: `db/migrate/XXXXXX_add_purpose_to_chats.rb`
- Modify: `app/models/chat.rb`

- [ ] **Step 1: Generate migration**

```bash
rails generate migration AddPurposeToChats purpose:string
```

- [ ] **Step 2: Edit the migration**

```ruby
class AddPurposeToChats < ActiveRecord::Migration[8.0]
  def change
    add_column :chats, :purpose, :string, default: "conversation"
    add_index :chats, :purpose
  end
end
```

- [ ] **Step 3: Run migration**

```bash
rails db:migrate
```

- [ ] **Step 4: Add scopes to Chat model**

In `app/models/chat.rb`, add:

```ruby
scope :conversations, -> { where(purpose: "conversation") }
scope :system, -> { where.not(purpose: "conversation") }
```

- [ ] **Step 5: Run tests**

Run: `rails test`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add purpose column to chats for system AI tracking"
```

---

## Task 9: Post::AiSummarizable — GenerateSummaryJob → RubyLLM

**Files:**
- Create: `app/models/concerns/post/ai_summarizable.rb`
- Modify: `app/models/post.rb`
- Modify: `app/jobs/generate_summary_job.rb`

- [ ] **Step 1: Create the concern**

```ruby
# app/models/concerns/post/ai_summarizable.rb
module Post::AiSummarizable
  extend ActiveSupport::Concern

  def generate_summary!(force: false)
    return if summary.present? && !force

    text_to_summarize = prepare_text_for_summary
    return if text_to_summarize.blank? || text_to_summarize.length < 50

    chat = user.chats.create!(
      purpose: "summary",
      model: Model.find_by(model_id: RubyLLM.configuration.default_model)
    )

    prompt = "Output ONLY a single teaser sentence. No preamble. Maximum 200 characters. Hook the reader with the most intriguing aspect.\n\nTeaser:\n\n#{text_to_summarize}"

    response = chat.ask(prompt)
    raw_summary = response.content

    return unless raw_summary.present?

    cleaned = clean_ai_summary(raw_summary)
    update!(summary: cleaned)
    broadcast_summary_update
  rescue => e
    Rails.logger.error "Failed to generate summary for post #{id}: #{e.message}"
  end

  private

  def prepare_text_for_summary
    if link?
      text = fetch_external_content
      text = "Title: #{title}\nURL: #{url}" if text.blank?
    else
      text = ActionView::Base.full_sanitizer.sanitize(content)
    end

    text.to_s.truncate(6000)
  end

  def clean_ai_summary(raw)
    cleaned = raw.gsub(/^(Here is a |Here's a |Here are |Teaser: |The teaser: |One-sentence teaser: )/i, "")
    cleaned = cleaned.gsub(/^(This article |This page |This resource |Learn about |Discover |Explore )/i, "")
    cleaned = cleaned.gsub(/^["'](.+)["']$/, '\1')
    cleaned.strip
  end

  def broadcast_summary_update
    Turbo::StreamsChannel.broadcast_replace_to(
      "post_#{id}",
      target: "post_#{id}_summary",
      partial: "posts/summary",
      locals: { post: self }
    )
  end
end
```

- [ ] **Step 2: Include concern in Post**

In `app/models/post.rb`, add:

```ruby
include Post::AiSummarizable
```

- [ ] **Step 3: Thin out the job**

Replace `app/jobs/generate_summary_job.rb`:

```ruby
class GenerateSummaryJob < ApplicationJob
  queue_as :default

  def perform(post, force: false)
    post.generate_summary!(force: force)
  end
end
```

- [ ] **Step 4: Run tests**

Run: `rails test`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: move summary generation to Post::AiSummarizable, use RubyLLM"
```

---

## Task 10: Testimonial::AiGeneratable + rename job

**Files:**
- Create: `app/models/concerns/testimonial/ai_generatable.rb`
- Modify: `app/models/testimonial.rb`
- Rename: `app/jobs/generate_testimonial_fields_job.rb` → `app/jobs/generate_testimonial_job.rb`
- Rename: `test/jobs/generate_testimonial_fields_job_test.rb` → `test/jobs/generate_testimonial_job_test.rb`

- [ ] **Step 1: Create the concern**

```ruby
# app/models/concerns/testimonial/ai_generatable.rb
module Testimonial::AiGeneratable
  extend ActiveSupport::Concern

  MAX_HEADING_RETRIES = 5

  def generate_ai_fields!
    existing_headings = Testimonial.where.not(id: id).where.not(heading: nil).pluck(:heading)

    user_context = [ user.display_name, user.bio, user.company ].compact_blank.join(", ")
    system_prompt = build_generation_prompt(existing_headings)
    user_prompt = "User: #{user_context}\nQuote: #{quote}"

    if ai_feedback.present? && ai_attempts > 0
      user_prompt += "\n\nPrevious feedback to address: #{ai_feedback}"
    end

    chat = user.chats.create!(
      purpose: "testimonial_generation",
      model: Model.find_by(model_id: RubyLLM.configuration.default_model)
    )

    parsed = ask_and_parse(chat, system_prompt, user_prompt)

    unless parsed
      update!(ai_feedback: "We couldn't process your testimonial right now. Please try again later.")
      broadcast_testimonial_update
      return
    end

    retries = 0
    while heading_taken?(parsed["heading"]) && retries < MAX_HEADING_RETRIES
      retries += 1
      existing_headings << parsed["heading"]
      retry_prompt = build_generation_prompt(existing_headings)
      parsed = ask_and_parse(chat, retry_prompt, user_prompt)
      break unless parsed
    end

    unless parsed
      update!(ai_feedback: "We couldn't process your testimonial right now. Please try again later.")
      broadcast_testimonial_update
      return
    end

    update!(
      heading: parsed["heading"],
      subheading: parsed["subheading"],
      body_text: parsed["body_text"]
    )
    ValidateTestimonialJob.perform_later(self)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse AI response for testimonial #{id}: #{e.message}"
    update!(ai_feedback: "We couldn't process your testimonial right now. Please try again later.")
    broadcast_testimonial_update
  end

  private

  def ask_and_parse(chat, system_prompt, user_prompt)
    response = chat.ask("#{system_prompt}\n\n#{user_prompt}")
    JSON.parse(response.content)
  rescue JSON::ParserError
    nil
  rescue => e
    Rails.logger.error "AI error in testimonial generation for #{id}: #{e.message}"
    nil
  end

  def heading_taken?(heading)
    Testimonial.where.not(id: id).exists?(heading: heading)
  end

  def build_generation_prompt(existing_headings)
    taken = if existing_headings.any?
              "These headings are ALREADY TAKEN and must NOT be used (pick a synonym or related concept instead): #{existing_headings.join(', ')}."
    else
              "No headings are taken yet — pick any fitting word."
    end

    <<~PROMPT
      You generate structured testimonial content for a Ruby programming language advocacy site.
      Given a user's quote about why they love Ruby, generate:

      1. heading: A unique 1-3 word heading that captures the THEME or FEELING of the quote.
         Be creative and specific. Go beyond generic words. Think of evocative nouns, metaphors, compound phrases, or poetic concepts.
         The heading must make sense as an answer to "Why Ruby?" — e.g. "Why Ruby?" → "Flow State", "Clarity", "Pure Joy".
         Good examples: "Spark", "Flow State", "Quiet Power", "Warm Glow", "First Love", "Playground", "Second Nature", "Deep Roots", "Readable Code", "Clean Slate", "Smooth Sailing", "Expressiveness", "Old Friend", "Sharp Tools", "Creative Freedom", "Solid Ground", "Calm Waters", "Poetic Logic", "Builder's Joy", "Sweet Spot", "Hidden Gem", "Fresh Start", "True North", "Clarity", "Belonging", "Empowerment", "Momentum", "Simplicity", "Trust", "Confidence"
         #{taken}
      2. subheading: A short tagline under 10 words.
      3. body_text: 2-3 sentences that EXTEND and DEEPEN the user's idea. Add new angles, examples, or implications.
         Do NOT repeat or paraphrase what the user already said. Build on top of it.

      WRITING STYLE — sound like a real person, not an AI:
      - NEVER use: delve, tapestry, landscape, foster, showcase, underscore, pivotal, vibrant, crucial, testament, additionally, interplay, intricate, enduring, garner, enhance
      - NEVER use inflated phrases: "serves as", "stands as", "is a testament to", "highlights the importance of", "reflects broader", "setting the stage"
      - NEVER use "It's not just X, it's Y" or "Not only X but also Y" parallelisms
      - NEVER use rule-of-three lists (e.g., "elegant, expressive, and powerful")
      - NEVER end with vague positivity ("the future looks bright", "exciting times ahead")
      - AVOID -ing tack-ons: "ensuring...", "highlighting...", "fostering..."
      - AVOID em dashes. Use commas or periods instead.
      - AVOID filler: "In order to", "It is important to note", "Due to the fact that"
      - USE simple verbs: "is", "has", "does" — not "serves as", "boasts", "features"
      - BE specific and concrete. Say what Ruby actually does, not how significant it is.
      - Write like a developer talking to a friend, not a press release.

      Respond with valid JSON only: {"heading": "...", "subheading": "...", "body_text": "..."}
    PROMPT
  end

end
```

Note: The `broadcast_testimonial_update` method shared by both AI concerns is extracted to the Testimonial model itself — see Task 11 Step 2.

- [ ] **Step 2: Include concern in Testimonial, update job reference**

In `app/models/testimonial.rb`, add:

```ruby
include Testimonial::AiGeneratable
```

Change the `process_quote_change` method from:

```ruby
GenerateTestimonialFieldsJob.perform_later(self)
```

to:

```ruby
GenerateTestimonialJob.perform_later(self)
```

- [ ] **Step 3: Rename and thin out the job**

```bash
git mv app/jobs/generate_testimonial_fields_job.rb app/jobs/generate_testimonial_job.rb
git mv test/jobs/generate_testimonial_fields_job_test.rb test/jobs/generate_testimonial_job_test.rb
```

Replace `app/jobs/generate_testimonial_job.rb`:

```ruby
class GenerateTestimonialJob < ApplicationJob
  queue_as :default

  def perform(testimonial)
    testimonial.generate_ai_fields!
  end
end
```

Replace `test/jobs/generate_testimonial_job_test.rb`:

```ruby
require "test_helper"

class GenerateTestimonialJobTest < ActiveJob::TestCase
  test "enqueues without error" do
    testimonial = testimonials(:unpublished)

    assert_nothing_raised do
      GenerateTestimonialJob.perform_later(testimonial)
    end
  end
end
```

- [ ] **Step 4: Run tests**

Run: `rails test`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: move testimonial generation to Testimonial::AiGeneratable, rename job"
```

---

## Task 11: Testimonial::AiValidatable — ValidateTestimonialJob → RubyLLM

**Files:**
- Create: `app/models/concerns/testimonial/ai_validatable.rb`
- Modify: `app/models/testimonial.rb`
- Modify: `app/jobs/validate_testimonial_job.rb`

- [ ] **Step 1: Create the concern**

```ruby
# app/models/concerns/testimonial/ai_validatable.rb
module Testimonial::AiValidatable
  extend ActiveSupport::Concern

  MAX_VALIDATION_ATTEMPTS = 3

  def validate_with_ai!
    existing = Testimonial.published.where.not(id: id)
      .pluck(:heading, :quote)
      .map { |h, q| "Heading: #{h}, Quote: #{q}" }
      .join("\n")

    system_prompt = build_validation_prompt(existing)

    user_prompt = <<~PROMPT
      Quote: #{quote}
      Generated heading: #{heading}
      Generated subheading: #{subheading}
      Generated body: #{body_text}
    PROMPT

    chat = user.chats.create!(
      purpose: "testimonial_validation",
      model: Model.find_by(model_id: RubyLLM.configuration.default_model)
    )

    response = chat.ask("#{system_prompt}\n\n#{user_prompt}")
    parsed = JSON.parse(response.content)

    if parsed["publish"]
      update!(published: true, ai_feedback: parsed["feedback"], reject_reason: nil)
    elsif parsed["reject_reason"] == "quote"
      update!(published: false, ai_feedback: parsed["feedback"], reject_reason: "quote")
    elsif ai_attempts < MAX_VALIDATION_ATTEMPTS
      update!(
        ai_attempts: ai_attempts + 1,
        ai_feedback: parsed["feedback"],
        reject_reason: "generation",
        published: false
      )
      GenerateTestimonialJob.perform_later(self)
    else
      update!(published: false, ai_feedback: parsed["feedback"], reject_reason: "generation")
    end

    broadcast_testimonial_update
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse validation response for testimonial #{id}: #{e.message}"
    update!(ai_feedback: "We couldn't validate your testimonial right now. Please try again later.")
    broadcast_testimonial_update
  rescue => e
    Rails.logger.error "Failed to validate testimonial #{id}: #{e.message}"
    update!(ai_feedback: "We couldn't validate your testimonial right now. Please try again later.")
    broadcast_testimonial_update
  end

  private

  def build_validation_prompt(existing_testimonials)
    <<~PROMPT
      You validate testimonials for a Ruby programming language advocacy site.

      CONTENT POLICY:
      - Hate speech, slurs, personal attacks, or targeted insults toward individuals or groups are NEVER allowed.
      - Casual expletives used positively (e.g., "Damn, Ruby is amazing!" or "Fuck, I love this language!") are ALLOWED.
      - The key distinction: profanity expressing enthusiasm = OK. Profanity attacking or demeaning people/groups = NOT OK.
      - The quote MUST express genuine love or appreciation for Ruby. This is an advocacy site — negative, dismissive, sarcastic, or trolling sentiments about Ruby are NOT allowed.

      VALIDATION RULES:
      1. First check the user's QUOTE against the content policy. If it violates (including being negative about Ruby), reject immediately with reject_reason "quote".
      2. If the quote is fine, check the AI-generated fields (heading/subheading/body). ONLY reject generation if there is a CLEAR problem:
         - The body contradicts or misrepresents the quote
         - The subheading is nonsensical or unrelated
         - The content is factually wrong about Ruby
         Do NOT reject for duplicate headings (handled elsewhere). Do NOT reject just because the fields could be "better" or "more creative". Good enough is good enough — publish it.
      3. If everything looks acceptable, publish it.

      AI-SOUNDING LANGUAGE CHECK:
      Reject with reason "generation" if the generated heading/subheading/body contains:
      - Words: delve, tapestry, landscape, foster, showcase, underscore, pivotal, vibrant, crucial, testament, additionally, interplay, intricate, enduring, garner, enhance
      - Patterns: "serves as", "stands as", "is a testament to", "not just X, it's Y", "not only X but also Y"
      - Rule-of-three adjective/noun lists
      - Vague positive endings ("the future looks bright", "exciting times ahead")
      - Superficial -ing tack-ons ("ensuring...", "highlighting...", "fostering...")
      If the quote itself is fine but the generated text sounds like AI wrote it, set reject_reason to "generation" and explain which phrases sound artificial.

      Existing published testimonials (for context):
      #{existing_testimonials.presence || "None yet."}

      Respond with valid JSON only: {"publish": true/false, "reject_reason": "quote" or "generation" or null, "feedback": "..."}
      - reject_reason "quote": the user's quote violates content policy or is not meaningful. Feedback should tell the USER what to fix.
      - reject_reason "generation": quote is fine but generated fields have a specific problem. Feedback must be a SPECIFIC INSTRUCTION for the AI generator, e.g., "The heading 'X' is already taken, use a different word" or "The body contradicts the quote by saying Y when the user said Z". Be concrete.
      - reject_reason null: publishing. Feedback should be a short positive note for the user.
    PROMPT
  end
end
```

- [ ] **Step 2: Include concern in Testimonial, add shared broadcast method**

In `app/models/testimonial.rb`, add:

```ruby
include Testimonial::AiValidatable
```

Add a shared private method to the Testimonial model itself (used by both AI concerns):

```ruby
private

def broadcast_testimonial_update
  Turbo::StreamsChannel.broadcast_replace_to(
    "testimonial_#{id}",
    target: "testimonial_section",
    partial: "testimonials/section",
    locals: { testimonial: self, user: user }
  )
end
```

- [ ] **Step 3: Thin out the job**

Replace `app/jobs/validate_testimonial_job.rb`:

```ruby
class ValidateTestimonialJob < ApplicationJob
  queue_as :default

  def perform(testimonial)
    testimonial.validate_with_ai!
  end
end
```

- [ ] **Step 4: Update test**

Replace `test/jobs/validate_testimonial_job_test.rb`:

```ruby
require "test_helper"

class ValidateTestimonialJobTest < ActiveJob::TestCase
  test "enqueues without error" do
    testimonial = testimonials(:unpublished)

    assert_nothing_raised do
      ValidateTestimonialJob.perform_later(testimonial)
    end
  end
end
```

- [ ] **Step 5: Run tests**

Run: `rails test`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: move testimonial validation to Testimonial::AiValidatable, use RubyLLM"
```

---

## Task 12: Remove ruby-openai and anthropic gems

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Remove gems from Gemfile**

Remove these lines:

```ruby
gem "ruby-openai", "~> 8.2"
gem "anthropic", "~> 1.6.0"
```

- [ ] **Step 2: Bundle**

```bash
bundle install
```

- [ ] **Step 3: Run tests**

Run: `rails test`
Expected: All pass (no code references these gems anymore)

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore: remove ruby-openai and anthropic gems, RubyLLM handles all AI"
```

---

## Task 13: Update AGENTS.md

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Rewrite AGENTS.md**

Rewrite to accurately describe WhyRuby's architecture post-refactor. Key sections:
- Project Overview (WhyRuby.info / RubyCommunity.org, Ruby 4.0.1 / Rails 8.2, Solid Stack)
- Authentication (GitHub OAuth, session-based, no Devise)
- Architecture (37signals vanilla Rails, fat models with concerns, thin controllers, no service objects)
- Data Model (Universal Content Model, key models, UUIDv7)
- AI Operations (RubyLLM, system chats with purpose for cost tracking, per-user spending)
- Concern Catalog (list all model concerns and what they do)
- Multi-Domain Setup (whyruby.info + rubycommunity.org)
- MCP (keep existing docs, it's functional)
- Development Commands, Testing, Deployment, Credentials

Remove template-specific sections about magic link auth, team billing/pricing details not relevant to WhyRuby.

- [ ] **Step 2: Run CI to verify nothing broke**

```bash
rails test && bundle exec rubocop && bin/brakeman --no-pager
```

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: rewrite AGENTS.md to reflect WhyRuby's actual architecture"
```

---

## Task 14: Final verification

- [ ] **Step 1: Run full CI pipeline**

```bash
bin/ci
```

Expected: All checks pass (RuboCop, tests, Brakeman, i18n)

- [ ] **Step 2: Verify no service references remain**

```bash
grep -r "app/services\|LocationNormalizer\|TimezoneResolver\|SvgSanitizer\|MetadataFetcher\|ImageProcessor\|SuccessStoryImageGenerator\|GithubDataFetcher\|GenerateTestimonialFieldsJob" app/ test/ --include="*.rb"
```

Expected: No matches

- [ ] **Step 3: Verify app/services/ directory is gone**

```bash
ls app/services/ 2>&1
```

Expected: "No such file or directory"
