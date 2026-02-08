# frozen_string_literal: true

namespace :locations do
  desc "Clear and re-normalize all user locations via geocoding"
  task refresh: :environment do
    User.update_all(normalized_location: nil, latitude: nil, longitude: nil)
    puts "Cleared all normalized locations and coordinates."

    distinct_locations = User.where.not(location: [ nil, "" ])
                             .distinct
                             .pluck(:location)

    total = distinct_locations.size
    puts "Normalizing #{total} distinct locations..."

    distinct_locations.each_with_index do |raw_location, index|
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

    Rails.cache.delete("community_map_data")
    puts "Done! #{User.where.not(latitude: nil).count} users have coordinates. Map cache cleared."
  end
end
