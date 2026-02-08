# frozen_string_literal: true

class TimezoneResolver
  def self.resolve(latitude, longitude)
    new.resolve(latitude, longitude)
  end

  def resolve(latitude, longitude)
    return "Etc/UTC" if latitude.nil? || longitude.nil?

    result = WhereTZ.lookup(latitude, longitude)
    timezone = result.is_a?(Array) ? result.first : result
    timezone.presence || "Etc/UTC"
  rescue StandardError => e
    Rails.logger.warn "Timezone lookup failed for (#{latitude}, #{longitude}): #{e.message}"
    "Etc/UTC"
  end
end
