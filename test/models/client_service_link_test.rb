require "test_helper"

class ClientServiceLinkTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Sync Test Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
  end

  # The enqueue trigger itself lives on Client#sync_linked_services now (see
  # client_test.rb) — a plain ClientServiceLink save, on its own, no longer
  # enqueues anything.

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
end
