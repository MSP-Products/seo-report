require "test_helper"

class EnqueueHubspotSyncJobTest < ActiveJob::TestCase
  test "enqueues a sync job for every kept client linked to HubSpot" do
    linked = Client.create!(name: "Linked Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    linked.client_service_links.create!(service: "hubspot", external_id: "company-123")

    assert_enqueued_with(job: SyncHubspotClientJob, args: [ linked.id ]) do
      EnqueueHubspotSyncJob.perform_now
    end
  end

  test "does not enqueue for a client with no hubspot link" do
    unlinked = Client.create!(name: "Unlinked Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    EnqueueHubspotSyncJob.perform_now

    assert_not_includes enqueued_client_ids, unlinked.id
  end

  test "does not enqueue for a client whose hubspot link has no external_id" do
    blank_link = Client.create!(name: "Blank Link Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    blank_link.client_service_links.create!(service: "hubspot", external_id: nil)

    EnqueueHubspotSyncJob.perform_now

    assert_not_includes enqueued_client_ids, blank_link.id
  end

  test "does not enqueue for a discarded client" do
    client = Client.create!(name: "Gone Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    client.client_service_links.create!(service: "hubspot", external_id: "company-999")
    client.discard
    # Creating the link above enqueues its own immediate sync
    # (ClientServiceLink#enqueue_hubspot_sync) — irrelevant here, so clear it and
    # only look at what EnqueueHubspotSyncJob itself enqueues below.
    clear_enqueued_jobs

    EnqueueHubspotSyncJob.perform_now

    assert_not_includes enqueued_client_ids, client.id
  end

  test "includes a pending client, so a client that just went active in HubSpot is still picked up" do
    pending = Client.create!(name: "Pending Practice #{SecureRandom.hex(4)}", onboarding_status: "pending")
    pending.client_service_links.create!(service: "hubspot", external_id: "company-456")

    assert_includes enqueued_client_ids_from { EnqueueHubspotSyncJob.perform_now }, pending.id
  end

  private

  def enqueued_client_ids
    enqueued_jobs.select { |job| job["job_class"] == "SyncHubspotClientJob" }.map { |job| job["arguments"].first }
  end

  def enqueued_client_ids_from
    yield
    enqueued_client_ids
  end
end
