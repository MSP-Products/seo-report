require "test_helper"

class LinkedServiceConnectionTesterTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Test Practice #{SecureRandom.hex(4)}", onboarding_status: "active",
      website_url: "example.com")
    AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "ghl-token", refresh_token: "ghl-refresh", company_id: "company-abc"
    }.to_json, expires_at: 23.hours.from_now)
    AgencyConnection.create!(service: "yext", encrypted_credentials: { api_key: "yext-key" }.to_json)
  end

  test "records success on a healthy link and clears any previous error" do
    link = @client.client_service_links.create!(service: "ghl", external_id: "location-123",
      override_credentials: { access_token: "loc-token" }.to_json)
    link.update_columns(last_sync_error: "stale error from a previous run")
    stub_request(:get, "https://services.leadconnectorhq.com/calendars/")
      .with(query: hash_including("locationId" => "location-123")).to_return(status: 200, body: { calendars: [] }.to_json)

    LinkedServiceConnectionTester.new.call

    link.reload
    assert_nil link.last_sync_error
    assert link.last_synced_at.present?
  end

  test "records the error on a broken link without touching the others" do
    broken = @client.client_service_links.create!(service: "ghl", external_id: "location-123",
      override_credentials: { access_token: "loc-token" }.to_json)
    healthy = @client.client_service_links.create!(service: "yext", external_id: "entity-123")
    stub_request(:get, "https://services.leadconnectorhq.com/calendars/")
      .with(query: hash_including("locationId" => "location-123")).to_return(status: 404, body: "not found")
    stub_request(:get, "https://api.yextapis.com/v2/accounts/me/entities/entity-123")
      .with(query: hash_including("api_key" => "yext-key")).to_return(status: 200, body: { response: {} }.to_json)

    LinkedServiceConnectionTester.new.call

    assert_match(/ghl/, broken.reload.last_sync_error)
    assert_nil healthy.reload.last_sync_error
  end

  test "skips unlinked services and HubSpot" do
    @client.client_service_links.create!(service: "ghl", external_id: "")
    hubspot_link = @client.client_service_links.create!(service: "hubspot", external_id: "company-123")

    LinkedServiceConnectionTester.new.call

    assert_not_requested :get, "https://services.leadconnectorhq.com/calendars/"
    assert_nil hubspot_link.reload.last_synced_at
  end

  test "skips discarded clients" do
    @client.update!(onboarding_status: "offboarded")
    @client.discard
    @client.client_service_links.create!(service: "ghl", external_id: "location-123")

    LinkedServiceConnectionTester.new.call

    assert_not_requested :get, "https://services.leadconnectorhq.com/calendars/"
  end
end
