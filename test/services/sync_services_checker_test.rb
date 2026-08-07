require "test_helper"

class SyncServicesCheckerTest < ActiveSupport::TestCase
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

  test "checks every service with a blank external_id, skipping already-linked ones" do
    @client.client_service_links.create!(service: "yext", external_id: "already-linked")
    stub_request(:get, GHL_LOCATIONS_URL).with(query: hash_including({})).to_return(status: 200, body: { locations: [] }.to_json)
    stub_request(:get, SEMRUSH_PROJECTS_URL).with(query: hash_including({})).to_return(status: 200, body: [].to_json)

    outcomes = SyncServicesChecker.new(@client).call

    assert_equal %w[ghl semrush], outcomes.keys.sort
    assert_equal false, outcomes["ghl"]
    assert_equal false, outcomes["semrush"]
  end

  test "returns a Match for a service that finds one" do
    stub_request(:get, GHL_LOCATIONS_URL).with(query: hash_including({}))
      .to_return(status: 200, body: { locations: [
        { "id" => "loc-1", "name" => "Adams Dental Associates", "website" => "https://www.adamsdentalassociates.com" }
      ] }.to_json)
    stub_request(:get, YEXT_ENTITIES_URL).with(query: hash_including({})).to_return(status: 200, body: { response: { entities: [] } }.to_json)
    stub_request(:get, SEMRUSH_PROJECTS_URL).with(query: hash_including({})).to_return(status: 200, body: [].to_json)

    outcomes = SyncServicesChecker.new(@client).call

    assert_equal "loc-1", outcomes["ghl"].location_id
  end

  test "isolates one service's failure from the others" do
    stub_request(:get, GHL_LOCATIONS_URL).with(query: hash_including({})).to_return(status: 500)
    stub_request(:get, YEXT_ENTITIES_URL).with(query: hash_including({}))
      .to_return(status: 200, body: { response: { entities: [
        { "meta" => { "id" => "ent-1" }, "name" => "Adams Dental Associates", "websiteUrl" => { "url" => "https://www.adamsdentalassociates.com" } }
      ] } }.to_json)
    stub_request(:get, SEMRUSH_PROJECTS_URL).with(query: hash_including({})).to_return(status: 200, body: [].to_json)

    outcomes = SyncServicesChecker.new(@client).call

    assert_equal :error, outcomes["ghl"]
    assert_equal "ent-1", outcomes["yext"].entity_id
    assert_equal false, outcomes["semrush"]
  end

  # Regression: the elapsed time used to be measured by the caller
  # (SyncClientServicesJob) around the *broadcast* rather than around the check,
  # so every ServiceSyncLog row recorded ~0ms and the countdown estimate built
  # from those rows (ServiceSyncLog.average_duration_for) was meaningless.
  # travel rather than sleep, per CLAUDE.md's "never sleep" rule.
  test "call_with_yields reports how long each check actually took" do
    %w[yext semrush].each { |service| @client.client_service_links.create!(service: service, external_id: "linked-#{service}") }
    stub_request(:get, GHL_LOCATIONS_URL).with(query: hash_including({})).to_return do
      travel 3.seconds
      { status: 200, body: { locations: [] }.to_json }
    end

    durations = {}
    # freeze_time first so the baseline has no sub-second remainder for `travel`
    # (which truncates) to throw away — otherwise the delta lands short of 3000.
    freeze_time do
      SyncServicesChecker.new(@client).call_with_yields { |service, _outcome, duration_ms| durations[service] = duration_ms }
    end

    assert_equal 3000, durations["ghl"]
  end

  test "returns an empty hash when every service is already linked" do
    %w[ghl yext semrush].each { |service| @client.client_service_links.create!(service: service, external_id: "linked-#{service}") }

    outcomes = SyncServicesChecker.new(@client).call

    assert_equal({}, outcomes)
    assert_not_requested :get, GHL_LOCATIONS_URL
  end
end
