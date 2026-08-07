require "test_helper"

class HubspotCompanySearcherTest < ActiveSupport::TestCase
  SEARCH_URL = "https://api.hubapi.com/crm/v3/objects/companies/search"

  setup do
    AgencyConnection.create!(service: "hubspot", encrypted_credentials: { access_token: "hubspot-agency-token" }.to_json)
  end

  test "returns matches from the search results" do
    stub_request(:post, SEARCH_URL)
      .with(headers: { "Authorization" => "Bearer hubspot-agency-token" },
        body: hash_including("filterGroups" => [
          { "filters" => [ { "propertyName" => "domain", "operator" => "CONTAINS_TOKEN", "value" => "adams" } ] },
          { "filters" => [ { "propertyName" => "name", "operator" => "CONTAINS_TOKEN", "value" => "adams" } ] }
        ]))
      .to_return(status: 200, body: { results: [
        { "id" => "12345", "properties" => { "name" => "Adams Dental Associates", "domain" => "adamsdentalassociates.com" } }
      ] }.to_json)

    matches = HubspotCompanySearcher.new("adams").call

    assert_equal 1, matches.size
    assert_equal "12345", matches.first.company_id
    assert_equal "Adams Dental Associates", matches.first.name
    assert_equal "adamsdentalassociates.com", matches.first.domain
  end

  test "returns an empty array without an HTTP call for a blank query" do
    assert_equal [], HubspotCompanySearcher.new("").call
    assert_not_requested :post, SEARCH_URL
  end

  test "returns an empty array without an HTTP call when there is no HubSpot connection" do
    AgencyConnection.find_by(service: "hubspot").destroy!

    assert_equal [], HubspotCompanySearcher.new("adams").call
    assert_not_requested :post, SEARCH_URL
  end

  test "returns an empty array when the search finds nothing" do
    stub_request(:post, SEARCH_URL).to_return(status: 200, body: { results: [] }.to_json)

    assert_equal [], HubspotCompanySearcher.new("nonexistent practice").call
  end

  test "an HTTP failure propagates unwrapped" do
    stub_request(:post, SEARCH_URL).to_return(status: 500)

    assert_raises(Faraday::Error) do
      HubspotCompanySearcher.new("adams").call
    end
  end
end
