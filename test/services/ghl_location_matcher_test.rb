require "test_helper"

class GhlLocationMatcherTest < ActiveSupport::TestCase
  LOCATIONS_URL = "https://services.leadconnectorhq.com/locations/search"

  setup do
    @client = Client.create!(name: "Adams Dental Associates #{SecureRandom.hex(4)}",
      onboarding_status: "active", website_url: "https://www.adamsdentalassociates.com/")
    AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "agency-access-token", refresh_token: "agency-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 23.hours.from_now)
  end

  test "finds a location whose website matches the client's, ignoring scheme/www/trailing slash" do
    stub_request(:get, LOCATIONS_URL)
      .with(query: hash_including("companyId" => "company-abc", "skip" => "0", "limit" => "100"))
      .to_return(status: 200, body: { locations: [
        { "id" => "loc-1", "name" => "Other Practice", "website" => "https://other-practice.com" },
        { "id" => "loc-2", "name" => "Adams Dental Associates", "website" => "http://www.AdamsDentalAssociates.com/" }
      ] }.to_json)

    match = GhlLocationMatcher.new(@client).call

    assert_equal "loc-2", match.location_id
    assert_equal "Adams Dental Associates", match.name
  end

  test "paginates through multiple pages of locations" do
    page_one = Array.new(100) { |i| { "id" => "loc-#{i}", "name" => "Practice #{i}", "website" => "https://practice-#{i}.com" } }
    stub_request(:get, LOCATIONS_URL)
      .with(query: hash_including("skip" => "0", "limit" => "100"))
      .to_return(status: 200, body: { locations: page_one }.to_json)
    stub_request(:get, LOCATIONS_URL)
      .with(query: hash_including("skip" => "100", "limit" => "100"))
      .to_return(status: 200, body: { locations: [
        { "id" => "loc-match", "name" => "Adams Dental Associates", "website" => "https://www.adamsdentalassociates.com" }
      ] }.to_json)

    match = GhlLocationMatcher.new(@client).call

    assert_equal "loc-match", match.location_id
  end

  test "returns nil when no location matches" do
    stub_request(:get, LOCATIONS_URL)
      .with(query: hash_including("skip" => "0", "limit" => "100"))
      .to_return(status: 200, body: { locations: [
        { "id" => "loc-1", "name" => "Other Practice", "website" => "https://other-practice.com" }
      ] }.to_json)

    assert_nil GhlLocationMatcher.new(@client).call
  end

  test "returns nil without an HTTP call when the client has no website_url" do
    @client.update!(website_url: nil)

    assert_nil GhlLocationMatcher.new(@client).call
    assert_not_requested :get, LOCATIONS_URL
  end

  test "returns nil without an HTTP call when there is no company_id on record" do
    AgencyConnection.find_by(service: "ghl").update!(encrypted_credentials: {
      access_token: "agency-access-token", refresh_token: "agency-refresh-token"
    }.to_json)

    assert_nil GhlLocationMatcher.new(@client).call
    assert_not_requested :get, LOCATIONS_URL
  end

  test "an HTTP failure propagates unwrapped" do
    stub_request(:get, LOCATIONS_URL).with(query: hash_including({})).to_return(status: 500)

    assert_raises(Faraday::Error) do
      GhlLocationMatcher.new(@client).call
    end
  end
end
