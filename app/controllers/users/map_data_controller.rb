class Users::MapDataController < ApplicationController
  def show
    data = Rails.cache.fetch("community_map_data", expires_in: 1.hour) do
      User.visible
          .where.not(latitude: nil, longitude: nil)
          .select(:id, :slug, :username, :name, :avatar_url, :latitude, :longitude, :open_to_work, :company, :normalized_location)
          .map { |u|
            {
              id: u.id,
              name: u.display_name,
              username: u.username,
              avatar_url: u.avatar_url,
              lat: u.latitude,
              lng: u.longitude,
              open_to_work: u.open_to_work,
              company: u.company,
              normalized_location: u.normalized_location,
              profile_url: helpers.community_user_url(u)
            }
          }
    end

    render json: data
  end
end
