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

  # HubSpot is the one service whose external_id drives more than report
  # data — it's the source of onboarding_status/onboarded_at/ai_seo_enrolled
  # (see SyncClientFromHubspot) — so a changed ID invalidates whatever the
  # last sync found immediately, rather than leaving a stale "Synced"/"Sync
  # failed" result on screen until the re-verification (Client
  # #sync_linked_services, triggered by the same save) completes.
  before_save :reset_sync_status, if: -> { hubspot? && external_id_changed? }

  # Per-client credential override (same JSON-blob shape as AgencyConnection#credentials).
  # Blank when the client uses the agency-wide connection for this service.
  def credentials
    return nil if override_credentials.blank?

    JSON.parse(override_credentials)
  end

  # Whether this link has ever been synced successfully (HubSpot-specific).
  def synced_recently?
    last_synced_at.present?
  end

  private

  # A changed ID invalidates whatever the last sync found — otherwise the
  # Sources/Overview UI keeps showing the previous ID's "Synced"/"Sync
  # failed" result until the new sync (enqueued above) happens to complete.
  def reset_sync_status
    self.last_synced_at = nil
    self.last_sync_error = nil
  end
end
