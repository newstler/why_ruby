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

    build_normalized_string(result)
  end

  private

  def photon_search(query)
    uri = URI(PHOTON_API)
    uri.query = URI.encode_www_form(q: query, limit: 1)

    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    feature = data.dig("features", 0, "properties")
    return nil unless feature

    OpenStruct.new(
      city: feature["city"],
      state: feature["state"],
      country_code: feature["countrycode"]
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
