# Fans out one SyncHubspotClientJob per kept client linked to HubSpot.
# Scheduled to run daily, ahead of EnqueueMonthlyReportsJob's monthly
# Client.kept.active targeting — without this, a client whose HubSpot
# onboarding status just changed would only be picked up on the report
# *after* next, since onboarding_status would otherwise only ever refresh as
# a side effect of a report already having run for them.
#
# Scoped to every kept client, not just currently-active ones, since a
# pending client going active in HubSpot is exactly the case this exists to
# catch quickly.
class EnqueueHubspotSyncJob < ApplicationJob
  queue_as :default

  def perform
    linked_client_ids = ClientServiceLink.where(service: "hubspot").where.not(external_id: [ nil, "" ]).select(:client_id)
    enqueued_count = 0

    Client.kept.where(id: linked_client_ids).find_each do |client|
      SyncHubspotClientJob.perform_later(client.id)
      enqueued_count += 1
    end

    Rails.logger.info("EnqueueHubspotSyncJob: enqueued #{enqueued_count} client(s)")
  end
end
