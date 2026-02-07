# frozen_string_literal: true

class NormalizeLocationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    normalized = LocationNormalizer.normalize(user.location)
    user.update_columns(normalized_location: normalized)
  end
end
