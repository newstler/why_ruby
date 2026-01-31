# frozen_string_literal: true

# Central configuration for domain names used across the application
Rails.application.config.x.domains = ActiveSupport::OrderedOptions.new
Rails.application.config.x.domains.primary = "whyruby.info"
Rails.application.config.x.domains.community = "rubycommunity.org"
