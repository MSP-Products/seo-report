require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "renders the first-report baseline: no revenue, no AI visibility, static intro" do
    report = build_monthly_report(
      client_attrs: { ai_seo_enrolled: false },
      report_attrs: { is_first_report: true },
      ghl_data_status: "not_connected"
    )

    get public_report_path(report.access_token)

    assert_response :success
    assert_select "span", text: "First report — baseline month"
    assert_select "strong", text: "?" # GHL appointments/revenue placeholder
    assert_select "h2", text: "Google & AI Search Performance", count: 0
  end

  test "renders an ongoing report with revenue, no AI SEO, and a flagged negative review" do
    report = build_monthly_report(
      client_attrs: { ai_seo_enrolled: false },
      report_attrs: { is_first_report: false },
      ghl_data_status: "connected",
      appointments_booked: 37,
      estimated_revenue: 18_400.00
    )
    report.gbp_reviews.create!(
      author_name: "Priya K.", posted_at: Date.new(2026, 6, 11), rating: 2,
      sentiment: "negative", needs_action: true, body: "Not the experience I expected."
    )

    get public_report_path(report.access_token)

    assert_response :success
    assert_select "h2", text: "Google & AI Search Performance", count: 0
    assert_select "strong", text: "Action needed:"
    assert_select "p", text: /\$18,400/
  end

  test "renders an ongoing report with AI SEO enrolled and no revenue" do
    report = build_monthly_report(
      client_attrs: { ai_seo_enrolled: true },
      report_attrs: { is_first_report: false },
      ghl_data_status: "not_connected",
      with_ai_visibility: true
    )
    report.create_report_highlight!(
      summary_text: "Great month overall.",
      ai_seo_summary_text: "AI visibility is climbing."
    )

    get public_report_path(report.access_token)

    assert_response :success
    assert_select "h2", text: "Google & AI Search Performance"
    assert_select "p", text: "AI SEO Update"
    assert_select "strong", text: "?"
  end

  test "404s for an unknown access token" do
    get public_report_path("does-not-exist")

    assert_response :not_found
    assert_select "h1", text: "Report not found"
  end

  private

  def build_monthly_report(client_attrs:, report_attrs:, ghl_data_status:, appointments_booked: nil,
                            estimated_revenue: nil, with_ai_visibility: false)
    client = Client.create!(
      { name: "Test Practice #{SecureRandom.hex(4)}", address: "1 Main St", website_url: "example.com",
        onboarding_status: "active" }.merge(client_attrs)
    )
    report = client.monthly_reports.create!(
      { report_month: Date.new(2026, 6, 1), generated_at: Time.current }.merge(report_attrs)
    )
    report.create_report_traffic!(
      total_visits: 217, unique_visitors: 59, pages_per_visit: 1.0,
      organic_visits: 59, direct_visits: 92, referral_visits: 41, paid_visits: 25,
      ghl_data_status: ghl_data_status, appointments_booked: appointments_booked, estimated_revenue: estimated_revenue
    )
    report.create_report_citation!(total_impressions: 900, total_engagements: 253, driving_directions_count: 178, website_clicks_count: 75)
    report.create_report_gbp_summary!(total_reviews: 10, average_rating: 4.5)

    if with_ai_visibility
      report.create_report_ai_visibility!(google_rank: 1, ai_rank: 6, overall_score: 26)
    end

    report
  end
end
