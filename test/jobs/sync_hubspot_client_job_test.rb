require "test_helper"

class SyncHubspotClientJobTest < ActiveJob::TestCase
  test "syncs the client from HubSpot" do
    client = Client.create!(name: "Old Name", onboarding_status: "pending")
    client.client_service_links.create!(service: "hubspot", external_id: "company-123")
    AgencyConnection.create!(service: "hubspot", encrypted_credentials: { access_token: "agency-token" }.to_json)

    stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-123")
      .with(query: hash_including("properties"))
      .to_return(
        status: 200,
        body: { properties: { name: "New Name", active: "true", service_purchased: "AI SEO" } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    SyncHubspotClientJob.perform_now(client.id)

    assert_equal "New Name", client.reload.name
    assert client.active?
  end

  test "discards rather than retries when the client no longer exists" do
    perform_enqueued_jobs do
      assert_nothing_raised do
        SyncHubspotClientJob.perform_later(SecureRandom.uuid)
      end
    end
  end

  test "enqueues on the default queue" do
    assert_equal "default", SyncHubspotClientJob.new.queue_name
  end
end
