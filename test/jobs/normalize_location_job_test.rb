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

  test "updates user normalized_location and coordinates" do
    user = users(:user_with_testimonial)
    user.update_columns(location: "NYC")

    stub_photon("NYC", city: "New York", countrycode: "us", lon: -74.006, lat: 40.7128)

    NormalizeLocationJob.perform_now(user.id)

    user.reload
    assert_equal "New York, US", user.normalized_location
    assert_in_delta 40.7128, user.latitude, 0.001
    assert_in_delta(-74.006, user.longitude, 0.001)
  end

  test "sets nil when geocoding fails" do
    user = users(:user_with_testimonial)
    user.update_columns(location: "Universe", normalized_location: "Old, US", latitude: 1.0, longitude: 1.0)

    stub_photon_empty("Universe")

    NormalizeLocationJob.perform_now(user.id)

    user.reload
    assert_nil user.normalized_location
    assert_nil user.latitude
    assert_nil user.longitude
  end

  test "handles non-existent user gracefully" do
    assert_nothing_raised do
      NormalizeLocationJob.perform_now("nonexistent-id")
    end
  end

  private

  def stub_photon(query, city:, countrycode:, state: nil, lon: 0.0, lat: 0.0)
    response = {
      type: "FeatureCollection",
      features: [ {
        type: "Feature",
        geometry: { type: "Point", coordinates: [ lon, lat ] },
        properties: { city: city, countrycode: countrycode, state: state }
      } ]
    }

    stub_request(:get, "https://photon.komoot.io/api/")
      .with(query: { q: query, limit: "1" })
      .to_return(status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_photon_empty(query)
    response = { type: "FeatureCollection", features: [] }

    stub_request(:get, "https://photon.komoot.io/api/")
      .with(query: { q: query, limit: "1" })
      .to_return(status: 200, body: response.to_json, headers: { "Content-Type" => "application/json" })
  end
end
