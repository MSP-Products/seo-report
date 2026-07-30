# Backs `encrypts :encrypted_credentials` (AgencyConnection) and
# `encrypts :override_credentials` (ClientServiceLink), per CONVENTIONS.md #19.
#
# Real deployments must set active_record_encryption.{primary_key,deterministic_key,
# key_derivation_salt} in config/credentials.yml.enc (bin/rails db:encryption:init
# generates values to paste in). Dev/test fall back to fixed local-only ENV defaults
# so the app boots without touching encrypted credentials.
config = Rails.application.credentials.active_record_encryption

primary_key = config&.dig(:primary_key) || ENV["AR_ENCRYPTION_PRIMARY_KEY"]
deterministic_key = config&.dig(:deterministic_key) || ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
key_derivation_salt = config&.dig(:key_derivation_salt) || ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]

if primary_key.blank? || deterministic_key.blank? || key_derivation_salt.blank?
  raise "Active Record encryption keys are not configured" if Rails.env.production?

  primary_key ||= "dev_insecure_primary_key_do_not_use_in_prod"
  deterministic_key ||= "dev_insecure_deterministic_key_do_not_use_in_prod"
  key_derivation_salt ||= "dev_insecure_key_derivation_salt_do_not_use_in_prod"
end

ActiveRecord::Encryption.configure(
  primary_key: primary_key,
  deterministic_key: deterministic_key,
  key_derivation_salt: key_derivation_salt
)
