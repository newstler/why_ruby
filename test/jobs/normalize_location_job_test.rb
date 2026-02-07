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

  test "updates user normalized_location" do
    user = users(:user_with_testimonial)
    user.update_columns(location: "NYC")

    stub_photon("NYC", city: "New York", countrycode: "us")

    NormalizeLocationJob.perform_now(user.id)

    user.reload
    assert_equal "New York, US", user.normalized_location
  end

  test "sets nil when geocoding fails" do
    user = users(:user_with_testimonial)
    user.update_columns(location: "Universe")

    stub_photon_empty("Universe")

    NormalizeLocationJob.perform_now(user.id)

    user.reload
    assert_nil user.normalized_location
  end

  test "handles non-existent user gracefully" do
    assert_nothing_raised do
      NormalizeLocationJob.perform_now("nonexistent-id")
    end
  end

  private

  def stub_photon(query, city:, countrycode:, state: nil)
    response = {
      type: "FeatureCollection",
      features: [ {
        type: "Feature",
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
