# Backs `encrypts :encrypted_credentials` (AgencyConnection) and
# `encrypts :override_credentials` (ClientServiceLink), per CONVENTIONS.md #19.
#
# Real deployments set AR_ENCRYPTION_PRIMARY_KEY / AR_ENCRYPTION_DETERMINISTIC_KEY /
# AR_ENCRYPTION_KEY_DERIVATION_SALT as real environment variables (e.g. in Railway's
# service Variables tab) — generate values with `bin/rails db:encryption:init`.
# Dev/test fall back to fixed local-only defaults so the app boots without them.
#
# `bin/rails assets:precompile` runs during the Docker build with no runtime secrets
# available at all (see Dockerfile: SECRET_KEY_BASE_DUMMY=1) — booting the full Rails
# environment for that step must not require real keys either, so it's exempted here
# the same way Rails exempts SECRET_KEY_BASE itself.
config = Rails.application.credentials.active_record_encryption

primary_key = config&.dig(:primary_key) || ENV["AR_ENCRYPTION_PRIMARY_KEY"]
deterministic_key = config&.dig(:deterministic_key) || ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
key_derivation_salt = config&.dig(:key_derivation_salt) || ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]

if primary_key.blank? || deterministic_key.blank? || key_derivation_salt.blank?
  if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
    raise "Active Record encryption keys are not configured"
  end

  primary_key ||= "dev_insecure_primary_key_do_not_use_in_prod"
  deterministic_key ||= "dev_insecure_deterministic_key_do_not_use_in_prod"
  key_derivation_salt ||= "dev_insecure_key_derivation_salt_do_not_use_in_prod"
end

ActiveRecord::Encryption.configure(
  primary_key: primary_key,
  deterministic_key: deterministic_key,
  key_derivation_salt: key_derivation_salt
)
