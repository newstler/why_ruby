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
      # Rate limit: Photon requires max 1 req/sec
      sleep(1.1) if index > 0

      result = LocationNormalizer.normalize(raw_location)

      if result
        User.where(location: raw_location).update_all(
          normalized_location: result[:normalized_location],
          latitude: result[:latitude],
          longitude: result[:longitude]
        )
        puts "[#{index + 1}/#{total}] \"#{raw_location}\" → #{result[:normalized_location]} (#{result[:latitude]}, #{result[:longitude]})"
      else
        puts "[#{index + 1}/#{total}] \"#{raw_location}\" → (no match)"
      end
    end

    puts "Done!"
  end

  desc "Backfill coordinates for users with normalized locations but no lat/lng"
  task backfill_coordinates: :environment do
    distinct_locations = User.where.not(location: [ nil, "" ])
                             .where(latitude: nil)
                             .distinct
                             .pluck(:location)

    total = distinct_locations.size
    puts "Backfilling coordinates for #{total} distinct locations..."

    distinct_locations.each_with_index do |raw_location, index|
      sleep(1.1) if index > 0

      result = LocationNormalizer.normalize(raw_location)

      if result
        User.where(location: raw_location).update_all(
          normalized_location: result[:normalized_location],
          latitude: result[:latitude],
          longitude: result[:longitude]
        )
        puts "[#{index + 1}/#{total}] \"#{raw_location}\" → (#{result[:latitude]}, #{result[:longitude]})"
      else
        puts "[#{index + 1}/#{total}] \"#{raw_location}\" → (no match)"
      end
    end

    puts "Done! #{User.where.not(latitude: nil).count} users now have coordinates."
  end
end
