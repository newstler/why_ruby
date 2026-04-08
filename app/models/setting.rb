class Setting < ApplicationRecord
  DEFAULT_AI_MODEL = "gpt-4.1-nano"

  ALLOWED_KEYS = %i[
    default_ai_model
    github_api_token
    github_rubycommunity_client_id github_rubycommunity_client_secret
    github_whyruby_client_id github_whyruby_client_secret
    litestream_replica_access_key litestream_replica_bucket litestream_replica_key_id
    mail_from
    public_chats
    smtp_address smtp_password smtp_username
    stripe_publishable_key stripe_secret_key stripe_webhook_secret
    summary_model testimonial_model translation_model
    trial_days
    validation_model
  ].freeze

  after_save :reconfigure!

  def self.instance
    first || create!
  end

  def self.get(key, default: nil)
    raise ArgumentError, "Unknown setting: #{key}" unless ALLOWED_KEYS.include?(key.to_sym)
    value = instance.public_send(key)
    value.presence || default
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    default
  end

  def self.provider_configured?(provider)
    ProviderCredential.configured?(provider)
  end

  def self.chats_enabled?
    get(:public_chats) != false && Model.configured_providers.any?
  end

  def self.reconfigure!
    instance.reconfigure!
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
    # DB not ready yet — skip
  end

  def reconfigure!
    ProviderCredential.configure_ruby_llm!
    configure_default_model!
    configure_stripe!
    configure_smtp!
    configure_litestream!
  end

  private

  def configure_default_model!
    return unless has_attribute?(:default_ai_model)
    model = default_ai_model.presence || DEFAULT_AI_MODEL
    RubyLLM.configure { |config| config.default_model = model }
  end

  def configure_stripe!
    Stripe.api_key = stripe_secret_key
  end

  def configure_smtp!
    ActionMailer::Base.default_options = { from: mail_from } if has_attribute?(:mail_from) && mail_from.present?

    return unless Rails.env.production?
    return if smtp_address.blank?

    ActionMailer::Base.smtp_settings = {
      address: smtp_address,
      user_name: smtp_username,
      password: smtp_password,
      port: 587,
      authentication: :plain
    }
  end

  def configure_litestream!
    return unless Rails.application.config.respond_to?(:litestream)

    Rails.application.config.litestream.replica_bucket = litestream_replica_bucket
    Rails.application.config.litestream.replica_key_id = litestream_replica_key_id
    Rails.application.config.litestream.replica_access_key = litestream_replica_access_key
  end
end
