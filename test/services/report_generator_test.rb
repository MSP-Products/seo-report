require "test_helper"

class ReportGeneratorTest < ActiveSupport::TestCase
  setup do
    @month = Date.current.beginning_of_month - 1.month

    @client = Client.create!(name: "Test Practice", website_url: "example.com", onboarding_status: "active", ai_seo_enrolled: true)
    @client.client_service_links.create!(service: "hubspot", external_id: "company-1",
      override_credentials: { access_token: "hs-token" }.to_json)
    @client.client_service_links.create!(service: "ghl", external_id: "location-1",
      override_credentials: { access_token: "ghl-token" }.to_json)
    @client.client_service_links.create!(service: "yext", external_id: "entity-1",
      override_credentials: { api_key: "yext-key" }.to_json)
    @client.client_service_links.create!(service: "semrush", external_id: "project-1",
      override_credentials: { api_key: "semrush-key" }.to_json)
    @keyword = @client.client_keywords.create!(keyword: "dentist near me", intent: "T")

    stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-1")
      .with(query: hash_including("properties"))
      .to_return(status: 200, body: { properties: { name: "Test Practice", ai_seo_enrolled: "true" } }.to_json)

    stub_request(:get, "https://services.leadconnectorhq.com/calendars/events")
      .with(query: hash_including("locationId"))
      .to_return(status: 200, body: { events: [ { id: "1" } ] }.to_json)
    stub_request(:get, "https://services.leadconnectorhq.com/opportunities/search")
      .with(query: hash_including("location_id"))
      .to_return(status: 200, body: { opportunities: [ { monetaryValue: 500 } ] }.to_json)

    yext_reports_url = "https://api.yextapis.com/v2/accounts/me/analytics/reports"
    stub_request(:post, yext_reports_url)
      .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [ "TOTAL_LISTINGS_IMPRESSIONS" ]))
      .to_return(status: 200, body: { response: { data: [ { "LOCATION_IDS" => "entity-1", "Total Listings Impressions" => 900 } ] } }.to_json)
    stub_request(:post, yext_reports_url)
      .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [ "TOTAL_LISTINGS_ACTIONS" ]))
      .to_return(status: 200, body: { response: { data: [ { "ENTITY_IDS" => "entity-1", "TOTAL_LISTINGS_ACTIONS" => 253 } ] } }.to_json)
    stub_request(:post, yext_reports_url)
      .with(query: hash_including("api_key" => "yext-key"), body: hash_including("metrics" => [
        "SCOUT_AI_AVG_OVERALL_VISIBILITY_SCORE", "SCOUT_GOOGLE_RANK", "SCOUT_AI_RANK_SCORE",
        "SCOUT_NEGATIVE_SENTIMENT_SCORE", "SCOUT_NEUTRAL_SENTIMENT_SCORE"
      ]))
      .to_return(status: 200, body: { response: { data: [ {
        "ENTITY_IDS" => "entity-1", "SCOUT_AI_AVG_OVERALL_VISIBILITY_SCORE" => 26, "SCOUT_GOOGLE_RANK" => 1,
        "SCOUT_AI_RANK_SCORE" => 6, "SCOUT_NEGATIVE_SENTIMENT_SCORE" => 0.03, "SCOUT_NEUTRAL_SENTIMENT_SCORE" => 0.33
      } ] } }.to_json)
    stub_request(:post, yext_reports_url)
      .with(query: hash_including("api_key" => "yext-key"), body: hash_including("dimensions" => [ "AI_MODEL", "ENTITY_IDS" ]))
      .to_return(status: 200, body: { response: { data: [ { "AI_MODEL" => "GEMINI", "ENTITY_IDS" => "entity-1", "SCOUT_AI_RANK_SCORE" => 6 } ] } }.to_json)
    stub_request(:get, "https://api.yextapis.com/v2/accounts/me/reviews")
      .with(query: hash_including("limit" => "1"))
      .to_return(status: 200, body: { response: { count: 312, averageRating: 4.7 } }.to_json)
    stub_request(:get, "https://api.yextapis.com/v2/accounts/me/reviews")
      .with(query: hash_including("limit" => "100"))
      .to_return(status: 200, body: { response: { reviews: [
        { "id" => 1, "authorName" => "Jess", "rating" => 5, "content" => "Great!",
          "publisherDate" => Time.current.to_i * 1000, "comments" => [] }
      ] } }.to_json)
    stub_request(:get, "https://api.yextapis.com/v2/accounts/me/posts")
      .with(query: hash_including("entityIds" => "entity-1"))
      .to_return(status: 200, body: { response: { posts: [
        { "postTitle" => "Hi", "text" => "Hello", "postDate" => (@month + 1.day).strftime("%Y-%m-%d %H:%M:%S") }
      ] } }.to_json)
    stub_request(:get, "https://api.yextapis.com/v2/accounts/me/entities/entity-1")
      .with(query: hash_including("api_key" => "yext-key"))
      .to_return(status: 200, body: { response: { photoGallery: [] } }.to_json)

    stub_request(:get, "https://api.semrush.com/reports/v1/projects/project-1/tracking/")
      .with(query: hash_including("key" => "semrush-key", "type" => "tracking_position_organic",
        "action" => "report", "url" => "*.example.com/*"))
      .to_return(status: 200, body: {
        data: { "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => 7 },
          "Tr" => { "20260630" => { "*.example.com/*" => 0.81 } } } }
      }.to_json)
  end

  test "generates a full report from all adapters" do
    report = ReportGenerator.new(client: @client, month: @month).call

    assert report.generated_at.present?
    assert_equal @month, report.report_month
    assert report.is_first_report?

    assert_equal "connected", report.report_traffic.ghl_data_status
    assert_equal 1, report.report_traffic.appointments_booked
    assert_equal 500, report.report_traffic.estimated_revenue.to_i
    assert_nil report.report_traffic.total_visits # GA4 stub always leaves this nil

    assert_equal 900, report.report_citation.total_impressions

    assert report.report_ai_visibility.present?
    assert_equal 26, report.report_ai_visibility.overall_score

    assert_equal 312, report.report_gbp_summary.total_reviews
    assert_equal 1, report.gbp_posts.count
    assert_equal 1, report.gbp_reviews.count

    ranking = report.report_keyword_rankings.first
    assert_equal 7, ranking.position
    assert_nil ranking.previous_position # no prior month's report exists yet

    assert_equal "success", report.report_generation_logs.last.status
    assert report.report_generation_logs.last.duration_seconds >= 0
  end

  test "snapshots only pages first seen within the report month" do
    in_month = @client.sitemap_pages.create!(url: "https://example.com/new-page/", title: "New Page",
      meta_description: "Fresh content", first_seen_at: @month.beginning_of_month + 3.days)
    @client.sitemap_pages.create!(url: "https://example.com/old-page/", title: "Old Page",
      first_seen_at: @month - 2.months)

    report = ReportGenerator.new(client: @client, month: @month).call

    published = report.report_pages_published
    assert_equal 1, published.count
    assert_equal in_month.id, published.first.sitemap_page_id
    assert_equal "New Page", published.first.title
    assert_equal "Fresh content", published.first.description
  end

  test "is idempotent — re-running updates rather than duplicating" do
    ReportGenerator.new(client: @client, month: @month).call
    report = ReportGenerator.new(client: @client, month: @month).call

    assert_equal 1, @client.monthly_reports.where(report_month: @month).count
    assert_equal 1, report.report_keyword_rankings.count
    assert_equal 2, report.report_generation_logs.count
  end

  test "carries the previous month's position forward as previous_position" do
    earlier_month = @month - 1.month
    stub_request(:get, "https://api.semrush.com/reports/v1/projects/project-1/tracking/")
      .with(query: hash_including("key" => "semrush-key", "type" => "tracking_position_organic",
        "action" => "report", "url" => "*.example.com/*"))
      .to_return(
        { status: 200, body: { data: { "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => 12 },
          "Tr" => { "20260530" => { "*.example.com/*" => 0.50 } } } } }.to_json },
        { status: 200, body: { data: { "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => 7 },
          "Tr" => { "20260630" => { "*.example.com/*" => 0.81 } } } } }.to_json }
      )

    ReportGenerator.new(client: @client, month: earlier_month).call
    report = ReportGenerator.new(client: @client, month: @month).call

    assert_equal 12, report.report_keyword_rankings.first.previous_position
    assert_equal 7, report.report_keyword_rankings.first.position
  end

  test "marks GHL not_connected without calling the GHL API when no link exists" do
    @client.client_service_links.find_by(service: "ghl").destroy!

    report = ReportGenerator.new(client: @client, month: @month).call

    assert_equal "not_connected", report.report_traffic.ghl_data_status
    assert_not_requested :get, "https://services.leadconnectorhq.com/calendars/events"
  end

  test "does not create AI visibility data for a client not enrolled in AI SEO" do
    # HubSpot is the source of truth for enrollment (see #sync_hubspot) — the
    # generator reads *this run's* HubSpot data, not a locally-set flag.
    stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-1")
      .with(query: hash_including("properties"))
      .to_return(status: 200, body: { properties: { name: "Test Practice", ai_seo_enrolled: "false" } }.to_json)

    report = ReportGenerator.new(client: @client, month: @month).call

    assert_nil report.report_ai_visibility
  end

  test "raises for the current month" do
    assert_raises(ReportGenerator::MonthNotCompleteError) do
      ReportGenerator.new(client: @client, month: Date.current).call
    end
  end

  test "logs a failed attempt and re-raises on an unexpected error" do
    # Malformed JSON from HubSpot raises JSON::ParserError — not a
    # Faraday::Error, so it isn't caught by the adapter and propagates as a
    # genuine bug for the generator's top-level rescue to log.
    stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-1")
      .with(query: hash_including("properties"))
      .to_return(status: 200, body: "not json")

    assert_raises(JSON::ParserError) do
      ReportGenerator.new(client: @client, month: @month).call
    end

    report = @client.monthly_reports.find_by(report_month: @month)
    assert_equal "failed", report.report_generation_logs.last.status
    assert report.report_generation_logs.last.duration_seconds >= 0
  end
end
