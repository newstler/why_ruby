class Model < ApplicationRecord
  include Costable

  acts_as_model chats_foreign_key: :model_id
  has_many :chats, foreign_key: :model_id

  scope :enabled, -> { where(provider: configured_providers) }

  # Recalculate total cost from all chats
  def recalculate_total_cost!
    update_column(:total_cost, chats.sum(:total_cost))
  end

  # The same model_id exists once per provider, so pick a provider that is
  # actually configured — otherwise the call fails at request time.
  def self.resolve(model_id)
    enabled.find_by(model_id: model_id) || find_by(model_id: model_id)
  end

  def self.configured_providers
    distinct.pluck(:provider).select do |provider|
      Setting.provider_configured?(provider)
    end
  end
end
