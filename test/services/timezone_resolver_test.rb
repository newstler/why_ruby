# frozen_string_literal: true

require "test_helper"

class TimezoneResolverTest < ActiveSupport::TestCase
  test "resolves New York coordinates" do
    result = TimezoneResolver.resolve(40.7128, -74.006)
    assert_equal "America/New_York", result
  end

  test "resolves Berlin coordinates" do
    result = TimezoneResolver.resolve(52.52, 13.405)
    assert_equal "Europe/Berlin", result
  end

  test "resolves Tokyo coordinates" do
    result = TimezoneResolver.resolve(35.6762, 139.6503)
    assert_equal "Asia/Tokyo", result
  end

  test "returns Etc/UTC for nil latitude" do
    assert_equal "Etc/UTC", TimezoneResolver.resolve(nil, -74.006)
  end

  test "returns Etc/UTC for nil longitude" do
    assert_equal "Etc/UTC", TimezoneResolver.resolve(40.7128, nil)
  end

  test "returns Etc/UTC for both nil" do
    assert_equal "Etc/UTC", TimezoneResolver.resolve(nil, nil)
  end

  test "returns Etc/UTC for ocean coordinates" do
    result = TimezoneResolver.resolve(0.0, 0.0)
    assert_equal "Etc/UTC", result
  end
end
