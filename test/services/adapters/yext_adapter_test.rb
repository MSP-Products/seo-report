require "test_helper"

module Adapters
  class YextAdapterTest < ActiveSupport::TestCase
    setup do
      @client = Client.create!(name: "Test Practice", onboarding_status: "active")
      @client.client_service_links.create!(service: "yext", external_id: "entity-123",
        override_credentials: { api_key: "yext-key" }.to_json)
      @report_month = Date.new(2026, 6, 1)
      @reports_url = "https://api.yextapis.com/v2/accounts/me/analytics/reports"
      @reviews_url = "https://api.yextapis.com/v2/accounts/me/reviews"
      @posts_url = "https://api.yextapis.com/v2/accounts/me/posts"
      @entity_url = "https://api.yextapis.com/v2/accounts/me/entities/entity-123"
    end

    def stub_gbp_failure
      stub_request(:get, @reviews_url).with(query: hash_including("api_key" => "yext-key")).to_return(status: 500, body: "error")
      stub_request(:get, @posts_url).with(query: hash_including("api_key" => "yext-key")).to_return(status: 500, body: "error")
      stub_request(:get, @entity_url).with(query: hash_including("api_key" => "yext-key")).to_return(status: 500, body: "error")
    end

    test "maps citations from two separate impressions/engagements report calls" do
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [ "TOTAL_LISTINGS_IMPRESSIONS" ]))
        .to_return(status: 200, body: { response: { data: [ { "LOCATION_IDS" => "entity-123", "Total Listings Impressions" => 652 } ] } }.to_json)
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [ "TOTAL_LISTINGS_ACTIONS" ]))
        .to_return(status: 200, body: { response: { data: [ { "ENTITY_IDS" => "entity-123", "TOTAL_LISTINGS_ACTIONS" => 129 } ] } }.to_json)
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [
          "SCOUT_AI_AVG_OVERALL_VISIBILITY_SCORE", "SCOUT_GOOGLE_RANK", "SCOUT_AI_RANK_SCORE",
          "SCOUT_NEGATIVE_SENTIMENT_SCORE", "SCOUT_NEUTRAL_SENTIMENT_SCORE"
        ]))
        .to_return(status: 403, body: "forbidden")
      stub_gbp_failure

      result = YextAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_equal 652, result.data[:citations][:total_impressions]
      assert_equal 129, result.data[:citations][:total_engagements]
      assert_nil result.data[:citations][:driving_directions_count]
      assert_nil result.data[:citations][:website_clicks_count]
    end

    test "maps AI visibility with sentiment converted from fractions to percentages and positive derived" do
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [ "TOTAL_LISTINGS_IMPRESSIONS" ]))
        .to_return(status: 200, body: { response: { data: [ { "LOCATION_IDS" => "entity-123", "Total Listings Impressions" => 10 } ] } }.to_json)
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [ "TOTAL_LISTINGS_ACTIONS" ]))
        .to_return(status: 200, body: { response: { data: [ { "ENTITY_IDS" => "entity-123", "TOTAL_LISTINGS_ACTIONS" => 2 } ] } }.to_json)
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [
          "SCOUT_AI_AVG_OVERALL_VISIBILITY_SCORE", "SCOUT_GOOGLE_RANK", "SCOUT_AI_RANK_SCORE",
          "SCOUT_NEGATIVE_SENTIMENT_SCORE", "SCOUT_NEUTRAL_SENTIMENT_SCORE"
        ]))
        .to_return(status: 200, body: { response: { data: [ {
          "ENTITY_IDS" => "entity-123",
          "SCOUT_AI_AVG_OVERALL_VISIBILITY_SCORE" => 30.25,
          "SCOUT_GOOGLE_RANK" => 1.0,
          "SCOUT_AI_RANK_SCORE" => 4.6,
          "SCOUT_NEGATIVE_SENTIMENT_SCORE" => 0.03,
          "SCOUT_NEUTRAL_SENTIMENT_SCORE" => 0.33
        } ] } }.to_json)
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("dimensions" => [ "AI_MODEL", "ENTITY_IDS" ]))
        .to_return(status: 200, body: { response: { data: [
          { "AI_MODEL" => "GEMINI", "ENTITY_IDS" => "entity-123", "SCOUT_AI_RANK_SCORE" => 3.0 },
          { "AI_MODEL" => "PERPLEXITY", "ENTITY_IDS" => "entity-123", "SCOUT_AI_RANK_SCORE" => 5.0 }
        ] } }.to_json)
      stub_gbp_failure

      result = YextAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      ai = result.data[:ai_visibility]
      assert_equal 30.25, ai[:overall_score]
      assert_equal 1.0, ai[:google_rank]
      assert_equal 3, ai[:sentiment_negative_pct]
      assert_equal 33, ai[:sentiment_neutral_pct]
      assert_equal 64, ai[:sentiment_positive_pct]
      assert_nil ai[:citation_own_site_pct]
      assert_equal({ "gemini" => 3.0, "perplexity" => 5.0 }, ai[:platform_scores])
    end

    test "still succeeds when AI visibility/GBP calls fail (citations alone is enough)" do
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [ "TOTAL_LISTINGS_IMPRESSIONS" ]))
        .to_return(status: 200, body: { response: { data: [ { "LOCATION_IDS" => "entity-123", "Total Listings Impressions" => 10 } ] } }.to_json)
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [ "TOTAL_LISTINGS_ACTIONS" ]))
        .to_return(status: 200, body: { response: { data: [ { "ENTITY_IDS" => "entity-123", "TOTAL_LISTINGS_ACTIONS" => 2 } ] } }.to_json)
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [
          "SCOUT_AI_AVG_OVERALL_VISIBILITY_SCORE", "SCOUT_GOOGLE_RANK", "SCOUT_AI_RANK_SCORE",
          "SCOUT_NEGATIVE_SENTIMENT_SCORE", "SCOUT_NEUTRAL_SENTIMENT_SCORE"
        ]))
        .to_return(status: 403, body: "forbidden")
      stub_gbp_failure

      result = YextAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_equal 10, result.data[:citations][:total_impressions]
      assert_nil result.data[:ai_visibility]
      gbp = result.data[:gbp]
      assert_nil gbp[:total_reviews]
      assert_equal [], gbp[:reviews]
      assert_equal [], gbp[:posts]
      assert_equal [], gbp[:photos]
    end

    test "maps GBP reviews (with owner replies), posts filtered to this month, and photos" do
      stub_request(:get, @reviews_url)
        .with(query: hash_including("limit" => "1"))
        .to_return(status: 200, body: { response: { count: 134, averageRating: 4.82, reviews: [] } }.to_json)
      stub_request(:get, @reviews_url)
        .with(query: hash_including("minPublisherDate" => "2026-06-01", "maxPublisherDate" => "2026-06-30"))
        .to_return(status: 200, body: { response: { count: 1, reviews: [
          {
            "id" => 1682059125, "rating" => 5.0, "content" => "Great practice!", "authorName" => "Rosemary Tyler",
            "publisherDate" => 1782355462103,
            "comments" => [ { "authorRole" => "BUSINESS_OWNER", "content" => "Thank you!", "publisherDate" => 1782416623069 } ]
          },
          { "id" => 111, "rating" => 1.0, "content" => "Bad visit", "authorName" => "Anon", "publisherDate" => 1782355462103, "comments" => [] }
        ] } }.to_json)
      stub_request(:get, @posts_url)
        .with(query: hash_including("api_key" => "yext-key"))
        .to_return(status: 200, body: { response: { posts: [
          { "postTitle" => "In June", "text" => "June post", "postDate" => "2026-06-17 16:41:30" },
          { "postTitle" => "Not June", "text" => "should be filtered out", "postDate" => "2026-05-01 12:00:00" }
        ] } }.to_json)
      stub_request(:get, @entity_url)
        .with(query: hash_including("api_key" => "yext-key"))
        .to_return(status: 200, body: { response: { photoGallery: [
          { "image" => { "url" => "https://example.com/photo1.jpg" }, "description" => "Office front" }
        ] } }.to_json)
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [ "TOTAL_LISTINGS_IMPRESSIONS" ]))
        .to_return(status: 200, body: { response: { data: [ { "LOCATION_IDS" => "entity-123", "Total Listings Impressions" => 10 } ] } }.to_json)
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [ "TOTAL_LISTINGS_ACTIONS" ]))
        .to_return(status: 200, body: { response: { data: [ { "ENTITY_IDS" => "entity-123", "TOTAL_LISTINGS_ACTIONS" => 2 } ] } }.to_json)
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [
          "SCOUT_AI_AVG_OVERALL_VISIBILITY_SCORE", "SCOUT_GOOGLE_RANK", "SCOUT_AI_RANK_SCORE",
          "SCOUT_NEGATIVE_SENTIMENT_SCORE", "SCOUT_NEUTRAL_SENTIMENT_SCORE"
        ]))
        .to_return(status: 403, body: "forbidden")

      result = YextAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      gbp = result.data[:gbp]
      assert_equal 134, gbp[:total_reviews]
      assert_equal 4.82, gbp[:average_rating]

      replied, unreplied = gbp[:reviews].partition { |r| r[:external_id] == 1682059125 }.map(&:first)
      assert_equal "Thank you!", replied[:owner_reply_text]
      assert replied[:owner_replied_at].present?
      assert_nil unreplied[:owner_reply_text]
      assert_nil unreplied[:owner_replied_at]

      assert_equal 1, gbp[:posts].size
      assert_equal "In June", gbp[:posts].first[:title]

      assert_equal 1, gbp[:photos].size
      assert_equal "https://example.com/photo1.jpg", gbp[:photos].first[:image_url]
      assert_equal "Office front", gbp[:photos].first[:caption]
    end

    test "fails the whole result when citations (the core, required call) fails" do
      stub_request(:post, @reports_url)
        .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [ "TOTAL_LISTINGS_IMPRESSIONS" ]))
        .to_return(status: 401, body: "unauthorized")

      result = YextAdapter.new(@client, report_month: @report_month).call

      assert_not result.success?
    end
  end
end
