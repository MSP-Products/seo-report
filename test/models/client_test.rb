require "test_helper"

class ClientTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "defaults to pending onboarding_status when not specified" do
    client = Client.create!(name: "Default Status Practice #{SecureRandom.hex(4)}")

    assert_equal "pending", client.onboarding_status
  end

  test "requires a name when there is no HubSpot company id" do
    client = Client.new(name: "")

    assert_not client.valid?
    assert_includes client.errors[:name], "can't be blank"
  end

  test "does not require a name when a HubSpot company id is present" do
    client = Client.new(name: "")
    client.client_service_links.build(service: "hubspot", external_id: "company-789")

    assert client.valid?
  end

  test "fills in a placeholder name when creating via HubSpot id with no name given" do
    client = Client.new(name: "")
    client.client_service_links.build(service: "hubspot", external_id: "company-789")

    client.valid?

    assert_match(/HubSpot/, client.name)
  end

  test "does not overwrite a manually entered name even with a HubSpot id present" do
    client = Client.new(name: "Manual Name")
    client.client_service_links.build(service: "hubspot", external_id: "company-789")

    client.valid?

    assert_equal "Manual Name", client.name
  end

  test "search scope matches by partial, case-insensitive name" do
    match = Client.create!(name: "Willow Dental #{SecureRandom.hex(4)}", onboarding_status: "active")
    other = Client.create!(name: "Oakview Clinic #{SecureRandom.hex(4)}", onboarding_status: "active")

    results = Client.search("willow")

    assert_includes results, match
    assert_not_includes results, other
  end

  test "by_status scope filters on onboarding_status, and returns everything when blank" do
    active = Client.create!(name: "Active Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    pending = Client.create!(name: "Pending Practice #{SecureRandom.hex(4)}", onboarding_status: "pending")

    assert_includes Client.by_status("active"), active
    assert_not_includes Client.by_status("active"), pending
    assert_includes Client.by_status(nil), active
    assert_includes Client.by_status(nil), pending
  end

  test "find_or_create_monthly_report marks the onboarding month as the first report, per HubSpot's onboarded_at" do
    client = Client.create!(name: "Onboarded Practice #{SecureRandom.hex(4)}", onboarding_status: "active",
      onboarded_at: Date.new(2026, 2, 19))

    report = client.find_or_create_monthly_report(Date.new(2026, 2, 1))

    assert report.is_first_report?
  end

  test "find_or_create_monthly_report does not mark a later month as first, even with no prior report" do
    # This is the exact case the HubSpot-sourced onboarding date fixes: a
    # client onboarded in February, backfilled starting in June — June is
    # not their first month even though no report exists before it yet.
    client = Client.create!(name: "Backfilled Practice #{SecureRandom.hex(4)}", onboarding_status: "active",
      onboarded_at: Date.new(2026, 2, 19))

    report = client.find_or_create_monthly_report(Date.new(2026, 6, 1))

    assert_not report.is_first_report?
  end

  test "find_or_create_monthly_report falls back to report history when onboarded_at is unknown" do
    client = Client.create!(name: "Unsynced Practice #{SecureRandom.hex(4)}", onboarding_status: "active",
      onboarded_at: nil)

    first = client.find_or_create_monthly_report(Date.new(2026, 5, 1))
    assert first.is_first_report?

    second = client.find_or_create_monthly_report(Date.new(2026, 6, 1))
    assert_not second.is_first_report?
  end

  test "find_or_create_monthly_report finds the same row on a second call, without changing is_first_report" do
    client = Client.create!(name: "Idempotent Practice #{SecureRandom.hex(4)}", onboarding_status: "active",
      onboarded_at: Date.new(2026, 3, 1))

    first_call = client.find_or_create_monthly_report(Date.new(2026, 3, 1))
    second_call = client.find_or_create_monthly_report(Date.new(2026, 3, 1))

    assert_equal first_call.id, second_call.id
    assert second_call.is_first_report?
  end

  test "hubspot_synced? is false with no HubSpot link at all" do
    client = Client.create!(name: "No Link Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    assert_not client.hubspot_synced?
  end

  test "hubspot_synced? is false when the link has a standing sync error" do
    client = Client.create!(name: "Broken Link Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    link = client.client_service_links.create!(service: "hubspot", external_id: "12334")
    # update_columns, not update! — ClientServiceLink#reset_sync_status wipes
    # last_sync_error on any external_id change, including on create, so a
    # normal write can never leave it set on a freshly linked record.
    link.update_columns(last_sync_error: "not found")

    assert_not client.hubspot_synced?
  end

  test "hubspot_synced? is true once linked with no standing error" do
    client = Client.create!(name: "Healthy Link Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    client.client_service_links.create!(service: "hubspot", external_id: "12334")

    assert client.hubspot_synced?
  end

  test "sync_linked_services enqueues the full HubSpot sync for a linked HubSpot service" do
    client = Client.new(name: "Sync Test Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    client.client_service_links.build(service: "hubspot", external_id: "company-123")

    client.save!

    assert_enqueued_with(job: SyncHubspotClientJob, args: [ client.id ])
  end

  test "sync_linked_services enqueues a lightweight connection check for a linked non-HubSpot service" do
    client = Client.new(name: "Sync Test Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    link = client.client_service_links.build(service: "google_analytics", external_id: "384938446")

    client.save!

    assert_enqueued_with(job: TestClientServiceConnectionJob, args: [ link.id ])
  end

  test "sync_linked_services skips a service with a blank external_id" do
    client = Client.new(name: "Sync Test Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    client.client_service_links.build(service: "ghl", external_id: "")

    assert_no_enqueued_jobs { client.save! }
  end

  # Regression: the old trigger lived on ClientServiceLink and only fired
  # when that specific link's external_id changed. Client#sync_linked_services
  # replaces it — any client save re-verifies every already-linked service,
  # not only the one field that was actually edited, since one form
  # submission can touch several links at once.
  test "sync_linked_services re-checks an untouched but already-linked service on any client save" do
    client = Client.create!(name: "Sync Test Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    link = client.client_service_links.create!(service: "yext", external_id: "entity-123")
    clear_enqueued_jobs

    client.update!(phone: "555-0100")

    assert_enqueued_with(job: TestClientServiceConnectionJob, args: [ link.id ])
  end

  test "sync_linked_services enqueues one job per linked service in a single save" do
    client = Client.new(name: "Sync Test Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    hubspot_link = client.client_service_links.build(service: "hubspot", external_id: "company-123")
    ghl_link = client.client_service_links.build(service: "ghl", external_id: "location-123")

    client.save!

    assert_enqueued_with(job: SyncHubspotClientJob, args: [ client.id ])
    assert_enqueued_with(job: TestClientServiceConnectionJob, args: [ ghl_link.id ])
    assert_not_equal hubspot_link.id, ghl_link.id
  end
end
