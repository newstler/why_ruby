# frozen_string_literal: true

class TimezoneResolver
  # Legacy IANA identifiers renamed in recent tzdata releases.
  # The wheretz gem still returns old names that newer system
  # zoneinfo packages no longer include.
  LEGACY_IDENTIFIERS = {
    "Europe/Kiev" => "Europe/Kyiv"
  }.freeze

  def self.resolve(latitude, longitude)
    new.resolve(latitude, longitude)
  end

  def self.normalize(timezone)
    return "Etc/UTC" if timezone.blank?

    normalized = LEGACY_IDENTIFIERS[timezone] || timezone
    TZInfo::Timezone.get(normalized)
    normalized
  rescue TZInfo::InvalidTimezoneIdentifier
    Rails.logger.warn "Unknown timezone identifier: #{timezone}, falling back to Etc/UTC"
    "Etc/UTC"
  end

  def resolve(latitude, longitude)
    return "Etc/UTC" if latitude.nil? || longitude.nil?

    result = WhereTZ.lookup(latitude, longitude)
    timezone = result.is_a?(Array) ? result.first : result
    self.class.normalize(timezone)
  rescue StandardError => e
    Rails.logger.warn "Timezone lookup failed for (#{latitude}, #{longitude}): #{e.message}"
    "Etc/UTC"
  end
end
