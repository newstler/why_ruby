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

  test "returns City, CC when geocoding succeeds with city" do
    stub_photon("NYC", city: "New York", countrycode: "us", state: "New York")

    assert_equal "New York, US", LocationNormalizer.normalize("NYC")
  end

  test "returns State, CC when geocoding succeeds without city" do
    stub_photon("California", city: nil, countrycode: "us", state: "California")

    assert_equal "California, US", LocationNormalizer.normalize("California")
  end

  test "returns just CC when only country code available" do
    stub_photon("Germany", city: nil, countrycode: "de", state: nil)

    assert_equal "DE", LocationNormalizer.normalize("Germany")
  end

  test "returns nil when geocoding returns no results" do
    stub_photon_empty("Universe")

    assert_nil LocationNormalizer.normalize("Universe")
  end

  test "returns nil when result has no country code" do
    stub_photon("Somewhere", city: "Somewhere", countrycode: nil, state: nil)

    assert_nil LocationNormalizer.normalize("Somewhere")
  end

  private

  def stub_photon(query, city:, countrycode:, state:)
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
