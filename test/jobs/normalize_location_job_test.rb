# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class NormalizeLocationJobTest < ActiveJob::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  teardown do
    WebMock.allow_net_connect!
  end

  test "delegates to user.geocode!" do
    user = users(:user_with_testimonial)
    user.update_columns(location: "NYC")

    stub_photon("NYC", city: "New York", countrycode: "us", lon: -74.006, lat: 40.7128)

    NormalizeLocationJob.perform_now(user.id)

    user.reload
    assert_equal "New York, US", user.normalized_location
  end

  test "handles non-existent user gracefully" do
    assert_nothing_raised do
      NormalizeLocationJob.perform_now("nonexistent-id")
    end
  end

  private

  def stub_photon(query, city:, countrycode:, lon: 0.0, lat: 0.0)
    response = {
      type: "FeatureCollection",
      features: [ {
        type: "Feature",
        geometry: { type: "Point", coordinates: [ lon, lat ] },
        properties: { city: city, countrycode: countrycode }
      } ]
    }

    stub_request(:get, "https://photon.komoot.io/api/")
      .with(query: { q: query, limit: "1" })
      .to_return(status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" })
  end
end
