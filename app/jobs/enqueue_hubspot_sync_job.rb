# Fans out one SyncHubspotClientJob per client with a HubSpot
# ClientServiceLink row. Scheduled to run hourly, ahead of
# EnqueueMonthlyReportsJob's monthly Client.kept.active targeting — without
# this, a client whose HubSpot onboarding status just changed would only be
# picked up on the report *after* next, since onboarding_status would
# otherwise only ever refresh as a side effect of a report already having
# run for them.
#
# Scoped to every such client regardless of status or external_id, including
# discarded (offboarded) ones and blank/never-connected ones — not just
# currently-active, kept, or already-linked ones. Three cases this exists to
# catch:
# - A pending client going active in HubSpot.
# - A discarded client whose HubSpot company was deleted
#   (SyncClientFromHubspot#sync_unverified_status normalizes it to
#   "offboarded", staying discarded) — without including discarded clients,
#   that normalization could only ever be triggered by an admin happening to
#   re-save the client's Edit form, since Client#skip_service_sync
#   deliberately skips the immediate on-save check right after an offboard.
# - A client whose HubSpot ID was cleared (or never set) — normalizes to
#   pending if kept, or offboarded if already discarded, via the same "not
#   connected" guard in SyncClientFromHubspot#fetch_result.
class EnqueueHubspotSyncJob < ApplicationJob
  queue_as :default

  def perform
    client_ids_with_hubspot_link = ClientServiceLink.where(service: "hubspot").select(:client_id)
    enqueued_count = 0

    Client.where(id: client_ids_with_hubspot_link).find_each do |client|
      SyncHubspotClientJob.perform_later(client.id)
      enqueued_count += 1
    end

    Rails.logger.info("EnqueueHubspotSyncJob: enqueued #{enqueued_count} client(s)")
  end
end
