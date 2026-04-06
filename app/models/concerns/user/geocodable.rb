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
