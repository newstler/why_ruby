# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class LocationNormalizerTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  teardown do
    WebMock.allow_net_connect!
  end

  test "returns nil for blank input" do
    assert_nil LocationNormalizer.normalize(nil)
    assert_nil LocationNormalizer.normalize("")
    assert_nil LocationNormalizer.normalize("   ")
  end

  test "returns nil for pure emoji input" do
    assert_nil LocationNormalizer.normalize("\u{1F30D}")
  end

  test "returns hash with normalized string and coordinates when geocoding succeeds with city" do
    stub_photon("NYC", city: "New York", countrycode: "us", state: "New York", lon: -74.006, lat: 40.7128)

    result = LocationNormalizer.normalize("NYC")
    assert_equal "New York, US", result[:normalized_location]
    assert_in_delta 40.7128, result[:latitude], 0.001
    assert_in_delta(-74.006, result[:longitude], 0.001)
  end

  test "returns State, CC when geocoding succeeds without city" do
    stub_photon("California", city: nil, countrycode: "us", state: "California", lon: -119.417, lat: 36.778)

    result = LocationNormalizer.normalize("California")
    assert_equal "California, US", result[:normalized_location]
    assert_in_delta 36.778, result[:latitude], 0.001
  end

  test "returns just CC when only country code available" do
    stub_photon("Germany", city: nil, countrycode: "de", state: nil, lon: 10.451, lat: 51.165)

    result = LocationNormalizer.normalize("Germany")
    assert_equal "DE", result[:normalized_location]
    assert_in_delta 51.165, result[:latitude], 0.001
  end

  test "returns nil when geocoding returns no results" do
    stub_photon_empty("Universe")

    assert_nil LocationNormalizer.normalize("Universe")
  end

  test "returns nil when result has no country code" do
    stub_photon("Somewhere", city: "Somewhere", countrycode: nil, state: nil, lon: 0.0, lat: 0.0)

    assert_nil LocationNormalizer.normalize("Somewhere")
  end

  private

  def stub_photon(query, city:, countrycode:, state:, lon: 0.0, lat: 0.0)
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
