require "test_helper"

class YextEntityMatcherTest < ActiveSupport::TestCase
  ENTITIES_URL = "https://api.yextapis.com/v2/accounts/me/entities"

  setup do
    @client = Client.create!(name: "Adams Dental Associates #{SecureRandom.hex(4)}",
      onboarding_status: "active", website_url: "https://www.adamsdentalassociates.com/")
    AgencyConnection.create!(service: "yext", encrypted_credentials: { api_key: "yext-agency-key" }.to_json)
  end

  test "finds an entity whose website matches the client's, ignoring scheme/www/trailing slash" do
    stub_request(:get, ENTITIES_URL)
      .with(query: hash_including("api_key" => "yext-agency-key", "offset" => "0"))
      .to_return(status: 200, body: { response: { entities: [
        { "meta" => { "id" => "ent-1" }, "name" => "Other Practice", "websiteUrl" => { "url" => "https://other-practice.com" } },
        { "meta" => { "id" => "ent-2" }, "name" => "Adams Dental Associates", "websiteUrl" => { "url" => "http://www.AdamsDentalAssociates.com/" } }
      ] } }.to_json)

    match = YextEntityMatcher.new(@client).call

    assert_equal "ent-2", match.entity_id
    assert_equal "Adams Dental Associates", match.name
  end

  test "paginates through multiple pages of entities" do
    page_one = Array.new(50) { |i| { "meta" => { "id" => "ent-#{i}" }, "name" => "Practice #{i}", "websiteUrl" => { "url" => "https://practice-#{i}.com" } } }
    stub_request(:get, ENTITIES_URL)
      .with(query: hash_including("offset" => "0"))
      .to_return(status: 200, body: { response: { entities: page_one } }.to_json)
    stub_request(:get, ENTITIES_URL)
      .with(query: hash_including("offset" => "50"))
      .to_return(status: 200, body: { response: { entities: [
        { "meta" => { "id" => "ent-match" }, "name" => "Adams Dental Associates", "websiteUrl" => { "url" => "https://www.adamsdentalassociates.com" } }
      ] } }.to_json)

    match = YextEntityMatcher.new(@client).call

    assert_equal "ent-match", match.entity_id
  end

  test "returns nil when no entity matches" do
    stub_request(:get, ENTITIES_URL)
      .with(query: hash_including("offset" => "0"))
      .to_return(status: 200, body: { response: { entities: [
        { "meta" => { "id" => "ent-1" }, "name" => "Other Practice", "websiteUrl" => { "url" => "https://other-practice.com" } }
      ] } }.to_json)

    assert_nil YextEntityMatcher.new(@client).call
  end

  test "returns nil without an HTTP call when the client has no website_url" do
    @client.update!(website_url: nil)

    assert_nil YextEntityMatcher.new(@client).call
    assert_not_requested :get, ENTITIES_URL
  end

  test "returns nil without an HTTP call when there is no Yext connection" do
    AgencyConnection.find_by(service: "yext").destroy!

    assert_nil YextEntityMatcher.new(@client).call
    assert_not_requested :get, ENTITIES_URL
  end

  test "an HTTP failure propagates unwrapped" do
    stub_request(:get, ENTITIES_URL).with(query: hash_including({})).to_return(status: 500)

    assert_raises(Faraday::Error) do
      YextEntityMatcher.new(@client).call
    end
  end
end
