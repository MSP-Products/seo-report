require "test_helper"

module Adapters
  class YextAdapterTest < ActiveSupport::TestCase
    setup do
      @client = Client.create!(name: "Test Practice", onboarding_status: "active")
      @client.client_service_links.create!(service: "yext", external_id: "entity-123",
        override_credentials: { api_key: "yext-key" }.to_json)
      @report_month = Date.new(2026, 6, 1)
    end

    test "maps citations, AI visibility, and GBP activity into one result" do
      stub_request(:get, "https://api.yextapis.com/v2/accounts/me/analytics/listings")
        .with(query: hash_including("locationId" => "entity-123", "api_key" => "yext-key"))
        .to_return(status: 200, body: {
          response: { impressions: 900, engagements: 253, engagementBreakdown: { drivingDirections: 178, websiteClicks: 75 } }
        }.to_json)

      stub_request(:get, "https://api.yextapis.com/v2/accounts/me/scout/ai-visibility")
        .with(query: hash_including("locationId" => "entity-123"))
        .to_return(status: 200, body: {
          response: { overallScore: 26, googleRank: 1, aiRank: 6, sentiment: { positive: 56, neutral: 44 } }
        }.to_json)

      stub_request(:get, "https://api.yextapis.com/v2/accounts/me/locations/entity-123/gbp-activity")
        .with(query: hash_including("api_key" => "yext-key"))
        .to_return(status: 200, body: {
          response: { posts: [ { title: "Hello", description: "World", publishedAt: "2026-06-01" } ], reviews: [], photos: [] }
        }.to_json)

      result = YextAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_equal 900, result.data[:citations][:total_impressions]
      assert_equal 26, result.data[:ai_visibility][:overall_score]
      assert_equal "Hello", result.data[:gbp][:posts].first[:title]
    end

    test "still succeeds when only the citations call works (AI visibility/GBP degrade to nil)" do
      stub_request(:get, "https://api.yextapis.com/v2/accounts/me/analytics/listings")
        .with(query: hash_including("locationId" => "entity-123"))
        .to_return(status: 200, body: { response: { impressions: 10, engagements: 2 } }.to_json)

      stub_request(:get, "https://api.yextapis.com/v2/accounts/me/scout/ai-visibility")
        .with(query: hash_including("locationId" => "entity-123"))
        .to_return(status: 500, body: "error")

      stub_request(:get, "https://api.yextapis.com/v2/accounts/me/locations/entity-123/gbp-activity")
        .with(query: hash_including("api_key" => "yext-key"))
        .to_return(status: 500, body: "error")

      result = YextAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_equal 10, result.data[:citations][:total_impressions]
      assert_nil result.data[:ai_visibility]
      assert_nil result.data[:gbp]
    end

    test "fails the whole result when citations (the core, required call) fails" do
      stub_request(:get, "https://api.yextapis.com/v2/accounts/me/analytics/listings")
        .with(query: hash_including("locationId" => "entity-123"))
        .to_return(status: 401, body: "unauthorized")

      result = YextAdapter.new(@client, report_month: @report_month).call

      assert_not result.success?
    end
  end
end
