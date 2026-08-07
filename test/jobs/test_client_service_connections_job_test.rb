require "test_helper"

class TestClientServiceConnectionsJobTest < ActiveJob::TestCase
  test "delegates to LinkedServiceConnectionTester" do
    client = Client.create!(name: "Test Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "ghl-token", refresh_token: "ghl-refresh", company_id: "company-abc"
    }.to_json, expires_at: 23.hours.from_now)
    client.client_service_links.create!(service: "ghl", external_id: "location-123",
      override_credentials: { access_token: "loc-token" }.to_json)
    stub_request(:get, "https://services.leadconnectorhq.com/calendars/")
      .with(query: hash_including("locationId" => "location-123")).to_return(status: 200, body: { calendars: [] }.to_json)

    TestClientServiceConnectionsJob.perform_now

    assert client.client_service_links.find_by(service: "ghl").last_synced_at.present?
  end
end
