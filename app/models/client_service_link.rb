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
  # (see SyncClientFromHubspot), so entering or changing it here re-syncs
  # immediately rather than waiting for the daily EnqueueHubspotSyncJob run.
  before_save :reset_sync_status, if: -> { hubspot? && external_id_changed? }
  # previously_new_record? || saved_change_to_external_id? guards the :update
  # case specifically because SyncClientFromHubspot#record_attempt writes
  # last_synced_at/last_sync_error back onto this same record after every
  # sync — without that guard, that write-back would itself re-trigger this
  # callback forever. (Two separate after_commit :enqueue_hubspot_sync
  # declarations, one per on:, don't work here — ActiveSupport::Callbacks
  # dedupes registrations by filter name, so the second silently replaces
  # the first instead of adding to it. One callback, one combined condition.)
  after_commit :enqueue_hubspot_sync, on: [ :create, :update ],
    if: -> { sync_hubspot_now? && (previously_new_record? || saved_change_to_external_id?) }

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

  def sync_hubspot_now?
    hubspot? && external_id.present?
  end

  def enqueue_hubspot_sync
    SyncHubspotClientJob.perform_later(client_id)
  end

  # A changed ID invalidates whatever the last sync found — otherwise the
  # Sources/Overview UI keeps showing the previous ID's "Synced"/"Sync
  # failed" result until the new sync (enqueued above) happens to complete.
  def reset_sync_status
    self.last_synced_at = nil
    self.last_sync_error = nil
  end
end
