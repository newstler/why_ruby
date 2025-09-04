# Set long-lived cache headers for ActiveStorage blobs and variants
# This ensures browsers and CDNs can cache images aggressively. It's safe
# because ActiveStorage blob/variant URLs are content-addressed and change
# whenever the underlying file changes.

Rails.application.config.to_prepare do
  next unless defined?(ActiveStorage::BaseController)

  ActiveStorage::BaseController.class_eval do
    before_action :set_long_cache_headers

    private

    def set_long_cache_headers
      response.headers["Cache-Control"] = "public, max-age=#{1.year.to_i}, immutable"
    end
  end
end
