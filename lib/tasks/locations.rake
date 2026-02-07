# frozen_string_literal: true

namespace :locations do
  desc "Normalize existing user locations via geocoding"
  task normalize: :environment do
    distinct_locations = User.where.not(location: [ nil, "" ])
                             .where(normalized_location: nil)
                             .distinct
                             .pluck(:location)

    total = distinct_locations.size
    puts "Normalizing #{total} distinct locations..."

    distinct_locations.each_with_index do |raw_location, index|
      # Rate limit: Nominatim requires max 1 req/sec
      sleep(1.1) if index > 0

      normalized = LocationNormalizer.normalize(raw_location)
      User.where(location: raw_location).update_all(normalized_location: normalized)

      status = normalized || "(no match)"
      puts "[#{index + 1}/#{total}] \"#{raw_location}\" → #{status}"
    end

    puts "Done!"
  end
end
