# frozen_string_literal: true

# Geocoder is used only for IP geolocation (country detection for analytics)
# Location string geocoding uses Photon API directly (see LocationNormalizer)

geoip_database = Rails.root.join("db", "GeoLite2-Country.mmdb")

if File.exist?(geoip_database)
  Geocoder.configure(
    ip_lookup: :geoip2,
    geoip2: { file: geoip_database },
    units: :km
  )
else
  Rails.logger.info "GeoLite2 database not found at #{geoip_database}. IP geolocation disabled."
  Geocoder.configure(ip_lookup: :test, units: :km)
end
