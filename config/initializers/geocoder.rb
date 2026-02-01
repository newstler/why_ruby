# frozen_string_literal: true

geoip_database = Rails.root.join("db", "GeoLite2-Country.mmdb")

if File.exist?(geoip_database)
  Geocoder.configure(
    # Use MaxMind GeoLite2 database for IP geolocation
    ip_lookup: :geoip2,
    geoip2: {
      file: geoip_database
    },

    # Set default units to kilometers
    units: :km,

    # Cache results to avoid repeated lookups (uses Rails.cache)
    cache: Rails.cache,
    cache_options: {
      expiration: 1.day
    }
  )
else
  # Fallback: disable IP lookup when database is not available
  # The client_country_code helper will return nil gracefully
  Rails.logger.info "GeoLite2 database not found at #{geoip_database}. IP geolocation disabled."

  Geocoder.configure(
    ip_lookup: :test,
    units: :km
  )
end
