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

    stub_request(:get, "https://api.yextapis.com/v2/accounts/me/analytics/listings")
      .with(query: hash_including("locationId"))
      .to_return(status: 200, body: { response: { impressions: 900, engagements: 253 } }.to_json)
    stub_request(:get, "https://api.yextapis.com/v2/accounts/me/scout/ai-visibility")
      .with(query: hash_including("locationId"))
      .to_return(status: 200, body: { response: { overallScore: 26, googleRank: 1, aiRank: 6 } }.to_json)
    stub_request(:get, "https://api.yextapis.com/v2/accounts/me/locations/entity-1/gbp-activity")
      .with(query: hash_including("api_key"))
      .to_return(status: 200, body: {
        response: {
          totalReviewCount: 312, averageRating: 4.7,
          posts: [ { title: "Hi", description: "Hello", publishedAt: "2026-06-01" } ],
          reviews: [ { id: "r1", authorName: "Jess", rating: 5, comment: "Great!", postedAt: "2026-06-02" } ],
          photos: []
        }
      }.to_json)

    stub_request(:get, "https://api.semrush.com/reports/v1/projects/project-1/tracking/rankings")
      .with(query: hash_including("key"))
      .to_return(status: 200, body: "Ph;Po;Pp\ndentist near me;7;0.81\n")
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
    stub_request(:get, "https://api.semrush.com/reports/v1/projects/project-1/tracking/rankings")
      .with(query: hash_including("key"))
      .to_return({ status: 200, body: "Ph;Po;Pp\ndentist near me;12;0.50\n" },
                 { status: 200, body: "Ph;Po;Pp\ndentist near me;7;0.81\n" })

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
  end
end
