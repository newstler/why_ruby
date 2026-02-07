# frozen_string_literal: true

class NormalizeLocationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    result = LocationNormalizer.normalize(user.location)

    if result
      user.update_columns(
        normalized_location: result[:normalized_location],
        latitude: result[:latitude],
        longitude: result[:longitude]
      )
    else
      user.update_columns(normalized_location: nil, latitude: nil, longitude: nil)
    end
  end
end
