require "test_helper"

class SyncClientFromHubspotTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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

  # Regression: a company deleted or unlinked in HubSpot 404s forever, so
  # leaving the client's last-known state untouched (the behavior for any
  # other failure) would mean it stays "active"/"offboarded" indefinitely
  # against a HubSpot record that no longer exists.
  test "reverts an active client to pending when the HubSpot company is gone" do
    @client.update!(onboarding_status: "active")
    stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-123")
      .with(query: hash_including("properties")).to_return(status: 404, body: "not found")

    result = SyncClientFromHubspot.new(@client).call

    assert_not result.success?
    assert_equal "pending", @client.reload.onboarding_status
  end

  # Regression: undiscarding here (the original behavior) meant a client
  # offboarded via the button with no working HubSpot connection got pulled
  # back out of "offboarded" on the very next scheduled sync, with no real
  # HubSpot signal actually telling us to bring it back — only the absence
  # of one. Discarded normalizes to "offboarded" and stays discarded instead.
  test "normalizes a discarded client to offboarded, staying discarded, when the HubSpot company is gone" do
    @client.update!(onboarding_status: "offboarded")
    @client.discard
    stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-123")
      .with(query: hash_including("properties")).to_return(status: 404, body: "not found")

    SyncClientFromHubspot.new(@client).call

    @client.reload
    assert_equal "offboarded", @client.onboarding_status
    assert @client.discarded?
  end

  test "reverts a kept client to pending when there is no HubSpot company id at all" do
    @client.client_service_links.destroy_all
    @client.update!(onboarding_status: "active")

    result = SyncClientFromHubspot.new(@client).call

    assert_not result.success?
    assert_equal "pending", @client.reload.onboarding_status
  end

  test "normalizes a discarded client to offboarded when there is no HubSpot company id at all" do
    @client.client_service_links.destroy_all
    @client.update!(onboarding_status: "offboarded")
    @client.discard

    SyncClientFromHubspot.new(@client).call

    @client.reload
    assert_equal "offboarded", @client.onboarding_status
    assert @client.discarded?
  end

  test "does not call HubSpot at all when there is no company id configured" do
    @client.client_service_links.destroy_all

    SyncClientFromHubspot.new(@client).call

    assert_not_requested :get, "https://api.hubapi.com/crm/v3/objects/companies/company-123"
  end

  # Regression: Client#after_commit fires on ANY save, whether or not an
  # attribute actually changed — so without setting skip_service_sync,
  # every client.update! below (success, not_found, or the discarded/kept
  # branch) would re-enqueue SyncHubspotClientJob via
  # Client#sync_linked_services, which calls this class again, forever. This
  # ran unbounded against the real HubSpot API in dev before being caught.
  test "does not re-enqueue its own sync job when it writes onto the client" do
    @client.update!(onboarding_status: "active")
    stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-123")
      .with(query: hash_including("properties")).to_return(status: 404, body: "not found")

    assert_no_enqueued_jobs(only: SyncHubspotClientJob) { SyncClientFromHubspot.new(@client).call }
  end

  test "does not re-enqueue its own sync job on a successful, state-changing sync" do
    stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-123")
      .with(query: hash_including("properties"))
      .to_return(status: 200, body: {
        properties: { name: "Real Practice Name", active: "true" }
      }.to_json, headers: { "Content-Type" => "application/json" })

    assert_no_enqueued_jobs(only: SyncHubspotClientJob) { SyncClientFromHubspot.new(@client).call }
  end
end
