require "test_helper"

class SyncClientFromHubspotTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Test Practice", onboarding_status: "pending")
    @client.client_service_links.create!(service: "hubspot", external_id: "company-123")
    AgencyConnection.create!(service: "hubspot", encrypted_credentials: { access_token: "agency-token" }.to_json)
  end

  test "writes the mapped fields onto the client" do
    stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-123")
      .with(query: hash_including("properties"))
      .to_return(
        status: 200,
        body: {
          properties: {
            name: "Real Practice Name", address: "3 Scripps Dr", website: "https://example.com",
            active: "true", service_purchased: "AI SEO", gmb_seo_start_date: "2024-02-19"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = SyncClientFromHubspot.new(@client).call

    assert result.success?
    @client.reload
    assert_equal "Real Practice Name", @client.name
    assert_equal "3 Scripps Dr", @client.address
    assert_equal "https://example.com", @client.website_url
    assert @client.active?
    assert @client.ai_seo_enrolled?
    assert_equal Date.new(2024, 2, 19), @client.onboarded_at
  end

  test "leaves the client untouched and returns the failure when HubSpot fails" do
    @client.update!(name: "Original Name")
    stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-123")
      .with(query: hash_including("properties"))
      .to_return(status: 401, body: "unauthorized")

    result = SyncClientFromHubspot.new(@client).call

    assert_not result.success?
    assert_equal "Original Name", @client.reload.name
  end
end
