# frozen_string_literal: true

class AgencyConnection < ApplicationRecord
  encrypts :encrypted_credentials

  # Enums
  enum :service, {
    semrush: "semrush",
    yext: "yext",
    google_analytics: "google_analytics",
    ghl: "ghl",
    hubspot: "hubspot"
  }, validate: true

  # prefix avoids "invalid?" clashing with ActiveRecord::Base#invalid? (validation state);
  # allow_nil since a connection has no status until first verified.
  enum :credential_status, {
    active: "active",
    expiring_soon: "expiring_soon",
    expired: "expired",
    invalid: "invalid"
  }, prefix: :credential, validate: { allow_nil: true }

  # Credentials are stored as a JSON blob (e.g. {"api_key" => "..."} or
  # {"access_token" => "...", "refresh_token" => "..."}) — shape varies per service.
  def credentials
    JSON.parse(encrypted_credentials.presence || "{}")
  end
end
