# Pulls a client's practice details and onboarding/AI-SEO status from HubSpot
# and writes them onto the Client record. Shared by ReportGenerator (as part
# of generating a report) and the standalone pre-generation sync job — the
# latter exists so EnqueueMonthlyReportsJob's Client.kept.active targeting
# reflects HubSpot's current state, not whatever a prior report run last
# wrote (a client that just went active in HubSpot wouldn't otherwise be
# picked up until the report after next).
class SyncClientFromHubspot
  def initialize(client)
    @client = client
    # Every update below is this sync's own write-back, not a fresh save
    # that should re-trigger anything — Client#after_commit fires on ANY
    # save regardless of whether an attribute actually changed, so without
    # this, client.update! here would re-enqueue SyncHubspotClientJob via
    # Client#sync_linked_services, which calls this class again, forever.
    @client.skip_service_sync = true
  end

  def call
    result = fetch_result
    record_attempt(result)
    return sync_unverified_status(result) if result.not_found
    return result unless result.success?

    client.update!(result.data.slice(:name, :address, :website_url, :onboarding_status, :onboarded_at, :ai_seo_enrolled).compact)

    # Soft-delete if HubSpot shows the client as offboarded
    client.discard if client.onboarding_status == "offboarded" && !client.discarded?
    # Restore if they become active again in HubSpot
    client.undiscard if client.onboarding_status != "offboarded" && client.discarded?

    result
  end

  private

  attr_reader :client

  # No company ID at all is treated exactly like a 404 below — both mean
  # "there is nothing on HubSpot's side to verify this client against right
  # now" — rather than the adapter's generic missing-credentials failure,
  # which would leave state untouched.
  def fetch_result
    return Adapters::Result.failure("hubspot: no company id configured for this client", not_found: true) if client.hubspot_link&.external_id.blank?

    Adapters::HubspotAdapter.new(client).call
  end

  # Not found — no company ID configured, or the linked company is gone
  # (deleted or unlinked on HubSpot's side) — is not a transient blip, so
  # unlike any other failure we don't leave the client's last-known state
  # untouched: we can't verify it against HubSpot at all right now. A kept
  # client degrades to "pending" — the honest "unverified" value. An
  # already-discarded client (most commonly: just offboarded via the button,
  # with no HubSpot connection to check against) normalizes to "offboarded"
  # instead and stays discarded — forcing it to "pending" here would
  # undiscard a client the admin just explicitly removed, with no real
  # HubSpot signal actually telling us to bring it back.
  def sync_unverified_status(result)
    client.update!(onboarding_status: client.discarded? ? "offboarded" : "pending")
    result
  end

  # last_synced_at only moves forward on success — it's "last time this
  # actually worked", not "last time we tried". last_sync_error mirrors
  # whichever attempt happened most recently, success or not, so the Sources
  # UI can show a currently-failing sync even after a prior success.
  def record_attempt(result)
    link = client.client_service_links.find_by(service: "hubspot")
    return if link.nil?

    if result.success?
      link.update!(last_synced_at: Time.current, last_sync_error: nil)
    else
      link.update!(last_sync_error: result.error)
    end
  end
end
