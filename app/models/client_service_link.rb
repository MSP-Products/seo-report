# frozen_string_literal: true

class ClientServiceLink < ApplicationRecord
  encrypts :override_credentials

  # Associations
  belongs_to :client

  # Enums
  enum :service, {
    semrush: "semrush",
    yext: "yext",
    google_analytics: "google_analytics",
    ghl: "ghl",
    hubspot: "hubspot"
  }, validate: true

  # prefix avoids "invalid?" clashing with ActiveRecord::Base#invalid? (validation state);
  # allow_nil since a link has no status until first verified.
  enum :credential_status, {
    active: "active",
    expiring_soon: "expiring_soon",
    expired: "expired",
    invalid: "invalid"
  }, prefix: :credential, validate: { allow_nil: true }

  # Validations
  validates :service, presence: true, uniqueness: { scope: :client_id }

  # Per-client credential override (same JSON-blob shape as AgencyConnection#credentials).
  # Blank when the client uses the agency-wide connection for this service.
  def credentials
    return nil if override_credentials.blank?

    JSON.parse(override_credentials)
  end
end
