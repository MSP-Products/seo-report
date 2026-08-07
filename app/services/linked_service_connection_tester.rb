# frozen_string_literal: true

# Hourly health check for every already-linked GHL, Yext, SEMrush, and GA4
# connection across every kept client — one lightweight API call per link,
# never a full report-data pull. Writes the outcome onto the same
# last_synced_at/last_sync_error columns client_source_status_label already
# reads, so a broken link shows up on the client's Sources tab well before
# the next real report run would surface it.
#
# HubSpot is deliberately excluded: SyncClientFromHubspot (enqueued hourly by
# EnqueueHubspotSyncJob) already tests that connection as a side effect of
# keeping onboarding_status current, so testing it again here would just be
# a second call against the same endpoint for no new information.
class LinkedServiceConnectionTester
  ADAPTERS = {
    "ghl" => Adapters::GhlAdapter,
    "yext" => Adapters::YextAdapter,
    "semrush" => Adapters::SemrushAdapter,
    "google_analytics" => Adapters::GoogleAnalyticsAdapter
  }.freeze

  # Shared with TestClientServiceConnectionJob, which calls this for one
  # link the moment its external_id is set or changed — the same
  # immediate-verification pattern ClientServiceLink already has for
  # HubSpot, just without HubSpot's extra state-syncing side effects.
  def self.test_link(link)
    return unless ADAPTERS.key?(link.service) && link.external_id.present?

    result = ADAPTERS.fetch(link.service).new(link.client, report_month: Date.current).call(action: :check_connection)
    record_attempt(link, result)
  end

  def self.record_attempt(link, result)
    if result.success?
      link.update!(last_synced_at: Time.current, last_sync_error: nil)
    else
      link.update!(last_sync_error: result.error)
    end
  end

  def call
    Client.kept.includes(:client_service_links).find_each do |client|
      client.client_service_links.each { |link| self.class.test_link(link) }
    end
  end
end
