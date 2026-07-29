# frozen_string_literal: true

class ClientServiceLink < ApplicationRecord
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

  enum :credential_status, {
    active: "active",
    expiring_soon: "expiring_soon",
    expired: "expired",
    invalid: "invalid"
  }, validate: true

  # Validations
  validates :service, presence: true, uniqueness: { scope: :client_id }
end
