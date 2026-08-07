require "test_helper"

class ClientServiceLinkTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @client = Client.create!(name: "Sync Test Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
  end

  test "enqueues a HubSpot sync when a company id is set on create" do
    assert_enqueued_with(job: SyncHubspotClientJob, args: [ @client.id ]) do
      @client.client_service_links.create!(service: "hubspot", external_id: "company-123")
    end
  end

  test "does not enqueue a HubSpot sync for a non-HubSpot service" do
    assert_no_enqueued_jobs only: SyncHubspotClientJob do
      @client.client_service_links.create!(service: "semrush", external_id: "company-123")
    end
  end

  test "does not enqueue a HubSpot sync when external_id is blank" do
    assert_no_enqueued_jobs only: SyncHubspotClientJob do
      @client.client_service_links.create!(service: "hubspot", external_id: "")
    end
  end

  test "enqueues again when the company id changes" do
    link = @client.client_service_links.create!(service: "hubspot", external_id: "company-123")
    clear_enqueued_jobs

    assert_enqueued_with(job: SyncHubspotClientJob, args: [ @client.id ]) do
      link.update!(external_id: "company-456")
    end
  end

  test "resets last_synced_at and last_sync_error when the company id changes" do
    link = @client.client_service_links.create!(service: "hubspot", external_id: "company-123")
    link.update_columns(last_synced_at: 1.hour.ago) # simulate a prior successful sync, bypassing the reset callback

    link.update!(external_id: "company-456")

    assert_nil link.last_synced_at
    assert_nil link.last_sync_error
  end

  test "does not reset sync status when saved without changing the company id" do
    link = @client.client_service_links.create!(service: "hubspot", external_id: "company-123")
    synced_at = 1.hour.ago
    link.update_columns(last_synced_at: synced_at) # simulate a prior successful sync, bypassing the reset callback

    link.update!(credential_status: "active")

    assert_in_delta synced_at.to_i, link.reload.last_synced_at.to_i, 1
  end

  test "does not re-enqueue a sync when saved without changing the company id" do
    link = @client.client_service_links.create!(service: "hubspot", external_id: "company-123")
    clear_enqueued_jobs

    # Mirrors what SyncClientFromHubspot#record_attempt does after every sync
    # attempt — this must not re-trigger enqueue_hubspot_sync, or every sync
    # would enqueue another sync forever.
    assert_no_enqueued_jobs only: SyncHubspotClientJob do
      link.update!(last_synced_at: Time.current)
    end
  end
end
