# frozen_string_literal: true

class NormalizeLocationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    result = LocationNormalizer.normalize(user.location)

    if result
      timezone = TimezoneResolver.resolve(result[:latitude], result[:longitude])
      user.update_columns(
        normalized_location: result[:normalized_location],
        latitude: result[:latitude],
        longitude: result[:longitude],
        timezone: timezone
      )
    else
      user.update_columns(normalized_location: nil, latitude: nil, longitude: nil, timezone: nil)
    end
  end
end
