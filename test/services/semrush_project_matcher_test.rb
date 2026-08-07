require "test_helper"

class SemrushProjectMatcherTest < ActiveSupport::TestCase
  PROJECTS_URL = "https://api.semrush.com/management/v1/projects"

  setup do
    @client = Client.create!(name: "Adams Dental Associates #{SecureRandom.hex(4)}",
      onboarding_status: "active", website_url: "https://www.adamsdentalassociates.com/")
    AgencyConnection.create!(service: "semrush", encrypted_credentials: { api_key: "semrush-agency-key" }.to_json)
  end

  test "finds a project+campaign whose domain matches the client's" do
    stub_request(:get, PROJECTS_URL)
      .with(query: hash_including("key" => "semrush-agency-key"))
      .to_return(status: 200, body: [
        { "project_id" => 111, "project_name" => "other-practice.com", "url" => "other-practice.com" },
        { "project_id" => 30632499, "project_name" => "adamsdentalassociates.com", "url" => "adamsdentalassociates.com" }
      ].to_json)
    stub_request(:get, "https://api.semrush.com/management/v1/projects/30632499/tracking/campaigns")
      .with(query: hash_including("key" => "semrush-agency-key"))
      .to_return(status: 200, body: { project_id: "30632499", campaigns: [
        { "id" => "30632499_5220001", "url" => "adamsdentalassociates.com" }
      ] }.to_json)

    match = SemrushProjectMatcher.new(@client).call

    assert_equal "30632499_5220001", match.project_campaign_id
    assert_equal "adamsdentalassociates.com", match.domain
  end

  test "prefers the campaign whose own url matches over the project's first campaign" do
    stub_request(:get, PROJECTS_URL)
      .with(query: hash_including("key" => "semrush-agency-key"))
      .to_return(status: 200, body: [
        { "project_id" => 30632499, "project_name" => "adamsdentalassociates.com", "url" => "adamsdentalassociates.com" }
      ].to_json)
    stub_request(:get, "https://api.semrush.com/management/v1/projects/30632499/tracking/campaigns")
      .with(query: hash_including("key" => "semrush-agency-key"))
      .to_return(status: 200, body: { campaigns: [
        { "id" => "30632499_1111111", "url" => "other-domain.com" },
        { "id" => "30632499_5220001", "url" => "www.adamsdentalassociates.com" }
      ] }.to_json)

    match = SemrushProjectMatcher.new(@client).call

    assert_equal "30632499_5220001", match.project_campaign_id
  end

  test "skips a domain-matching project whose campaigns call 404s (no tracking configured), tries the next" do
    stub_request(:get, PROJECTS_URL)
      .with(query: hash_including("key" => "semrush-agency-key"))
      .to_return(status: 200, body: [
        { "project_id" => 111, "project_name" => "www.adamsdentalassociates.com", "url" => "www.adamsdentalassociates.com", "tools" => [] },
        { "project_id" => 30632499, "project_name" => "adamsdentalassociates.com", "url" => "adamsdentalassociates.com",
          "tools" => [ { "tool" => "tracking" } ] }
      ].to_json)
    stub_request(:get, "https://api.semrush.com/management/v1/projects/30632499/tracking/campaigns")
      .with(query: hash_including("key" => "semrush-agency-key"))
      .to_return(status: 200, body: { campaigns: [ { "id" => "30632499_5220001", "url" => "adamsdentalassociates.com" } ] }.to_json)

    match = SemrushProjectMatcher.new(@client).call

    assert_equal "30632499_5220001", match.project_campaign_id
    assert_not_requested :get, "https://api.semrush.com/management/v1/projects/111/tracking/campaigns"
  end

  test "returns nil when no project matches" do
    stub_request(:get, PROJECTS_URL)
      .with(query: hash_including("key" => "semrush-agency-key"))
      .to_return(status: 200, body: [
        { "project_id" => 111, "project_name" => "other-practice.com", "url" => "other-practice.com" }
      ].to_json)

    assert_nil SemrushProjectMatcher.new(@client).call
  end

  test "returns nil without an HTTP call when the client has no website_url" do
    @client.update!(website_url: nil)

    assert_nil SemrushProjectMatcher.new(@client).call
    assert_not_requested :get, PROJECTS_URL
  end

  test "returns nil without an HTTP call when there is no SEMrush connection" do
    AgencyConnection.find_by(service: "semrush").destroy!

    assert_nil SemrushProjectMatcher.new(@client).call
    assert_not_requested :get, PROJECTS_URL
  end

  test "an HTTP failure propagates unwrapped" do
    stub_request(:get, PROJECTS_URL).with(query: hash_including({})).to_return(status: 500)

    assert_raises(Faraday::Error) do
      SemrushProjectMatcher.new(@client).call
    end
  end
end
