require "test_helper"
require "turbo/broadcastable/test_helper"

class SyncClientServicesJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  GHL_LOCATIONS_URL = "https://services.leadconnectorhq.com/locations/search"
  YEXT_ENTITIES_URL = "https://api.yextapis.com/v2/accounts/me/entities"
  SEMRUSH_PROJECTS_URL = "https://api.semrush.com/management/v1/projects"

  setup do
    @client = Client.create!(name: "Adams Dental Associates #{SecureRandom.hex(4)}",
      onboarding_status: "active", website_url: "https://www.adamsdentalassociates.com/")
    AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "ghl-agency-token", refresh_token: "ghl-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 23.hours.from_now)
    AgencyConnection.create!(service: "yext", encrypted_credentials: { api_key: "yext-agency-key" }.to_json)
    AgencyConnection.create!(service: "semrush", encrypted_credentials: { api_key: "semrush-agency-key" }.to_json)
  end

  test "broadcasts a replace for each unlinked service's result" do
    stub_request(:get, GHL_LOCATIONS_URL).with(query: hash_including({}))
      .to_return(status: 200, body: { locations: [
        { "id" => "loc-1", "name" => "Adams Dental Associates", "website" => "https://www.adamsdentalassociates.com" }
      ] }.to_json)
    stub_request(:get, YEXT_ENTITIES_URL).with(query: hash_including({})).to_return(status: 200, body: { response: { entities: [] } }.to_json)
    stub_request(:get, SEMRUSH_PROJECTS_URL).with(query: hash_including({})).to_return(status: 200, body: [].to_json)

    turbo_streams = capture_turbo_stream_broadcasts([ @client, :sync_services ]) do
      SyncClientServicesJob.perform_now(@client.id)
    end
    assert_equal 3, turbo_streams.size

    ghl_stream = turbo_streams.find { |s| s["target"] == "service_outcome_ghl" }
    yext_stream = turbo_streams.find { |s| s["target"] == "service_outcome_yext" }
    assert_equal "replace", ghl_stream["action"]
    assert_match "loc-1", ghl_stream.to_html
    assert_match "No match found", yext_stream.to_html

    # Regression: the "Use this match" button is wired by Stimulus' value naming
    # convention — a value named externalId on controller apply-suggestion must
    # render as data-apply-suggestion-external-id-value. A wrong name leaves a
    # button that silently does nothing, which no other assertion here catches.
    assert_match 'data-apply-suggestion-external-id-value="loc-1"', ghl_stream.to_html
  end

  test "logs one row per checked service, with the status the check returned" do
    stub_request(:get, GHL_LOCATIONS_URL).with(query: hash_including({}))
      .to_return(status: 200, body: { locations: [
        { "id" => "loc-1", "name" => "Adams Dental Associates", "website" => "https://www.adamsdentalassociates.com" }
      ] }.to_json)
    stub_request(:get, YEXT_ENTITIES_URL).with(query: hash_including({})).to_return(status: 200, body: { response: { entities: [] } }.to_json)
    stub_request(:get, SEMRUSH_PROJECTS_URL).with(query: hash_including({})).to_return(status: 500)

    SyncClientServicesJob.perform_now(@client.id)

    logs = ServiceSyncLog.where(client: @client).index_by(&:service)
    assert_equal "success", logs["ghl"].status
    assert_equal "not_found", logs["yext"].status
    assert_equal "error", logs["semrush"].status
  end

  test "does not broadcast anything when every service is already linked" do
    %w[ghl yext semrush].each { |service| @client.client_service_links.create!(service: service, external_id: "linked-#{service}") }

    assert_no_turbo_stream_broadcasts([ @client, :sync_services ]) do
      SyncClientServicesJob.perform_now(@client.id)
    end
  end
end
