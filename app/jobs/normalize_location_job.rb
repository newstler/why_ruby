# frozen_string_literal: true

class NormalizeLocationJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    user&.geocode!
  end
end
