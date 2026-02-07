# frozen_string_literal: true

require "net/http"
require "json"
require "ostruct"

class LocationNormalizer
  PHOTON_API = "https://photon.komoot.io/api/"

  def self.normalize(raw_location)
    new.normalize(raw_location)
  end

  def normalize(raw_location)
    return nil if raw_location.blank?

    # Skip strings that are clearly not geographic (pure emoji, etc.)
    stripped = raw_location.gsub(/[\p{Emoji_Presentation}\p{Extended_Pictographic}]/, "").strip
    return nil if stripped.empty?

    result = photon_search(raw_location)
    return nil unless result

    normalized_string = build_normalized_string(result)
    return nil unless normalized_string

    {
      normalized_location: normalized_string,
      latitude: result.latitude,
      longitude: result.longitude
    }
  end

  private

  def photon_search(query)
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

    OpenStruct.new(
      city: properties["city"],
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
    city = result.city
    country_code = result.country_code&.upcase

    return nil unless country_code.present?

    if city.present?
      "#{city}, #{country_code}"
    else
      state = result.state
      if state.present?
        "#{state}, #{country_code}"
      else
        country_code
      end
    end
  end
end
