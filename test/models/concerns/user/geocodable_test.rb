# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class User::GeocodableTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
    @user = users(:user_with_testimonial)
  end

  teardown do
    WebMock.allow_net_connect!
  end

  # --- Geocoding ---

  test "geocode! sets normalized_location, coordinates, and timezone" do
    @user.update_columns(location: "NYC")
    stub_photon("NYC", city: "New York", countrycode: "us", lon: -74.006, lat: 40.7128)

    @user.geocode!
    @user.reload

    assert_equal "New York, US", @user.normalized_location
    assert_in_delta 40.7128, @user.latitude, 0.001
    assert_in_delta(-74.006, @user.longitude, 0.001)
    assert_equal "America/New_York", @user.timezone
  end

  test "geocode! clears fields when geocoding fails" do
    @user.update_columns(location: "Universe", normalized_location: "Old, US", latitude: 1.0, longitude: 1.0, timezone: "America/New_York")
    stub_photon_empty("Universe")

    @user.geocode!
    @user.reload

    assert_nil @user.normalized_location
    assert_nil @user.latitude
    assert_nil @user.longitude
    assert_nil @user.timezone
  end

  test "geocode! returns nil for blank location" do
    @user.update_columns(location: nil)

    @user.geocode!
    @user.reload

    assert_nil @user.normalized_location
  end

  test "geocode! returns nil for pure emoji location" do
    @user.update_columns(location: "\u{1F30D}")

    @user.geocode!
    @user.reload

    assert_nil @user.normalized_location
  end

  test "geocode! returns State, CC when no city available" do
    @user.update_columns(location: "California")
    stub_photon("California", city: nil, countrycode: "us", state: "California", lon: -119.417, lat: 36.778)

    @user.geocode!
    @user.reload

    assert_equal "California, US", @user.normalized_location
  end

  test "geocode! returns just CC when only country code available" do
    @user.update_columns(location: "Germany")
    stub_photon("Germany", city: nil, countrycode: "de", state: nil, lon: 10.451, lat: 51.165)

    @user.geocode!
    @user.reload

    assert_equal "DE", @user.normalized_location
  end

  test "geocode! clears fields when result has no country code" do
    @user.update_columns(location: "Somewhere")
    stub_photon("Somewhere", city: "Somewhere", countrycode: nil, state: nil, lon: 0.0, lat: 0.0)

    @user.geocode!
    @user.reload

    assert_nil @user.normalized_location
  end

  # --- Timezone ---

  test "geocode! resolves Berlin coordinates to Europe/Berlin" do
    @user.update_columns(location: "Berlin")
    stub_photon("Berlin", city: "Berlin", countrycode: "de", lon: 13.405, lat: 52.52)

    @user.geocode!
    @user.reload

    assert_equal "Europe/Berlin", @user.timezone
  end

  test "geocode! resolves Kyiv coordinates to canonical Europe/Kyiv" do
    @user.update_columns(location: "Kyiv")
    stub_photon("Kyiv", city: "Kyiv", countrycode: "ua", lon: 30.52, lat: 50.45)

    @user.geocode!
    @user.reload

    assert_equal "Europe/Kyiv", @user.timezone
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
