# frozen_string_literal: true

class ClientServiceLink < ApplicationRecord
  encrypts :override_credentials

  # Associations
  belongs_to :client

  # Enums
  enum :service, Service::KEYS.index_by(&:itself), validate: true

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

  # Mirrors AgencyConnection#status_label/#status_dot_class (agency_connection.rb:66-82) with
  # per-client wording — "Linked" reads better than "Active" for one practice's account.
  def status_label
    return "Linked" if credential_active?
    return "Key expiring" if credential_expiring_soon?
    return "Auth error" if credential_expired? || credential_invalid?

    external_id.present? ? "Unverified" : "Not linked"
  end

  def status_dot_class
    return "bg-emerald-500" if credential_active?
    return "bg-amber-500" if credential_expiring_soon?
    return "bg-red-500" if credential_expired? || credential_invalid?

    "bg-slate-300"
  end
end
