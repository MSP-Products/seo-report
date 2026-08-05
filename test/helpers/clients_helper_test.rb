require "test_helper"

class ClientsHelperTest < ActionView::TestCase
  test "client_status_badge_class maps each onboarding_status to its badge color" do
    assert_equal "bg-emerald-50 text-emerald-700", client_status_badge_class(Client.new(onboarding_status: "active"))
    assert_equal "bg-amber-50 text-amber-700", client_status_badge_class(Client.new(onboarding_status: "pending"))
    assert_equal "bg-slate-100 text-slate-600", client_status_badge_class(Client.new(onboarding_status: "offboarded"))
  end

  test "client_source_status_label reflects external_id and credential_status" do
    assert_equal "Not linked", client_source_status_label(ClientServiceLink.new(external_id: nil))
    assert_equal "Auth error",
      client_source_status_label(ClientServiceLink.new(external_id: "x", credential_status: "invalid"))
    assert_equal "Expired",
      client_source_status_label(ClientServiceLink.new(external_id: "x", credential_status: "expired"))
    assert_equal "Key expiring",
      client_source_status_label(ClientServiceLink.new(external_id: "x", credential_status: "expiring_soon"))
    assert_equal "Linked", client_source_status_label(ClientServiceLink.new(external_id: "x"))
  end

  test "hubspot_sync_status_label distinguishes not linked, syncing, synced, and failed" do
    assert_equal "Not linked", hubspot_sync_status_label(nil)
    assert_equal "Not linked", hubspot_sync_status_label(ClientServiceLink.new(external_id: ""))
    assert_equal "Syncing…", hubspot_sync_status_label(ClientServiceLink.new(external_id: "x"))
    assert_equal "Sync failed",
      hubspot_sync_status_label(ClientServiceLink.new(external_id: "x", last_sync_error: "boom"))

    synced = ClientServiceLink.new(external_id: "x", last_synced_at: 5.minutes.ago)
    assert_match(/^Synced .* ago$/, hubspot_sync_status_label(synced))
  end

  test "hubspot_sync_status_dot_class matches the status label's color" do
    assert_equal "bg-slate-300", hubspot_sync_status_dot_class(nil)
    assert_equal "bg-amber-500", hubspot_sync_status_dot_class(ClientServiceLink.new(external_id: "x"))
    assert_equal "bg-red-500",
      hubspot_sync_status_dot_class(ClientServiceLink.new(external_id: "x", last_sync_error: "boom"))
    assert_equal "bg-emerald-500",
      hubspot_sync_status_dot_class(ClientServiceLink.new(external_id: "x", last_synced_at: Time.current))
  end

  test "hubspot_sync_error_message translates raw adapter errors into plain language" do
    assert_nil hubspot_sync_error_message(ClientServiceLink.new(last_sync_error: nil))

    assert_equal "No HubSpot company ID set for this practice yet.",
      hubspot_sync_error_message(ClientServiceLink.new(last_sync_error: "hubspot: no company id configured for this client"))

    assert_equal "HubSpot company ID not found — double-check the ID.",
      hubspot_sync_error_message(ClientServiceLink.new(last_sync_error: "hubspot request failed: the server responded with status 404 for GET ..."))

    assert_equal "HubSpot rejected the request — the connected account may not have access.",
      hubspot_sync_error_message(ClientServiceLink.new(last_sync_error: "hubspot request failed: the server responded with status 401 for GET ..."))

    assert_equal "HubSpot sync failed — try again, or check the company ID.",
      hubspot_sync_error_message(ClientServiceLink.new(last_sync_error: "some completely unrecognized failure"))
  end
end
