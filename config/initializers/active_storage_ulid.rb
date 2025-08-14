# Configure ActiveStorage to use ULIDs for primary keys
require "securerandom"

module ActiveStorageUlidSupport
  extend ActiveSupport::Concern

  included do
    before_create :set_ulid_if_needed
  end

  private

  def set_ulid_if_needed
    # Generate a ULID-like ID using the same format as other tables
    # ULID format: 01ARZ3NDEKTSV4RRFFQ69G5FAV (26 characters, Crockford Base32)
    if self.id.blank? && self.class.primary_key == "id"
      timestamp = (Time.now.to_f * 1000).to_i
      randomness = SecureRandom.random_bytes(10)

      # Create a 16-byte value (6 bytes timestamp + 10 bytes randomness)
      bytes = [ timestamp ].pack("Q>")[2..7] + randomness

      # Encode to Crockford Base32
      alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
      value = bytes.unpack1("H*").to_i(16)

      result = ""
      26.times do
        result = alphabet[value % 32] + result
        value /= 32
      end

      self.id = "01" + result[0..23]  # Ensure it starts with '01' like other ULIDs
    end
  end
end

# Apply to ActiveStorage models
Rails.application.config.to_prepare do
  if defined?(ActiveStorage::Blob)
    ActiveStorage::Blob.include ActiveStorageUlidSupport
  end

  if defined?(ActiveStorage::Attachment)
    ActiveStorage::Attachment.include ActiveStorageUlidSupport
  end

  if defined?(ActiveStorage::VariantRecord)
    ActiveStorage::VariantRecord.include ActiveStorageUlidSupport
  end
end
