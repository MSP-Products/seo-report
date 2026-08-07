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

  # Regression: this job used to exclude a blank external_id entirely, so a
  # client whose HubSpot link was cleared (or never set, but the row exists)
  # was never re-checked and could stay "active"/"offboarded" forever with
  # no working HubSpot connection to justify either. SyncClientFromHubspot's
  # "not connected" guard depends on this job actually running for it.
  test "still enqueues for a client whose hubspot link row exists with no external_id" do
    blank_link = Client.create!(name: "Blank Link Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    blank_link.client_service_links.create!(service: "hubspot", external_id: nil)
    clear_enqueued_jobs

    EnqueueHubspotSyncJob.perform_now

    assert_includes enqueued_client_ids, blank_link.id
  end

  # Regression: this job used to scope to Client.kept, so a client offboarded
  # because its HubSpot company was deleted (SyncClientFromHubspot#reset_to_pending)
  # could never be re-checked again automatically — the only way back to
  # pending was an admin happening to re-save that client's Edit form by hand.
  # HubSpot is the source of truth for this client's real status regardless
  # of discard state, so the scheduled re-check must cover discarded clients
  # too, in both directions (back to active, or to pending on a 404).
  test "still enqueues for a discarded client, since HubSpot may have changed since it was offboarded" do
    client = Client.create!(name: "Gone Practice #{SecureRandom.hex(4)}", onboarding_status: "offboarded")
    client.client_service_links.create!(service: "hubspot", external_id: "company-999")
    client.discard
    clear_enqueued_jobs

    EnqueueHubspotSyncJob.perform_now

    assert_includes enqueued_client_ids, client.id
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
