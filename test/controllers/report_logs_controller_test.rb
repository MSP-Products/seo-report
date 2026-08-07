require "test_helper"

class ReportLogsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get report_log_path

    assert_redirected_to login_path
  end

  test "an Account Manager cannot view the report log — it isn't in their role" do
    sign_in_as(role_key: "account_manager")

    get report_log_path

    assert_redirected_to root_path
  end

  test "lists a generated report with a link to view it" do
    sign_in_as(role_key: "admin")
    client = Client.create!(name: "Woodside Dental Care #{SecureRandom.hex(4)}", onboarding_status: "active")
    report = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generation_status: "ready",
      generated_at: Time.current)

    get report_log_path

    assert_response :success
    assert_select "h1", text: "Report Log"
    assert_select "p", text: client.name
    assert_select "a[href=?]", public_report_path(report.access_token)
  end

  test "does not link a report that isn't ready yet" do
    sign_in_as(role_key: "admin")
    client = Client.create!(name: "Bayview Family Dentistry #{SecureRandom.hex(4)}", onboarding_status: "active")
    report = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generation_status: "queued")

    get report_log_path

    assert_response :success
    assert_select "a[href=?]", public_report_path(report.access_token), count: 0
  end

  test "filters to one month when given" do
    sign_in_as(role_key: "admin")
    client = Client.create!(name: "Cedar Park Family Dentistry #{SecureRandom.hex(4)}", onboarding_status: "active")
    client.monthly_reports.create!(report_month: Date.new(2026, 5, 1), generation_status: "ready", generated_at: Time.current)
    client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generation_status: "ready", generated_at: Time.current)

    get report_log_path(month: "2026-05")

    assert_response :success
    assert_select "span", text: "May 2026"
    assert_select "span", text: "June 2026", count: 0
  end

  test "filters to one status when given" do
    sign_in_as(role_key: "admin")
    failed_client = Client.create!(name: "Summit Oral Surgery #{SecureRandom.hex(4)}", onboarding_status: "active")
    queued_client = Client.create!(name: "Clear Creek Orthodontics #{SecureRandom.hex(4)}", onboarding_status: "active")
    failed_client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generation_status: "failed", attempt_count: 2)
    queued_client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generation_status: "queued")

    get report_log_path(status: "failed")

    assert_response :success
    assert_match(/Failed ×2/, response.body)
    assert_no_match(/#{Regexp.escape(queued_client.name)}/, response.body)
  end

  test "status chips show real counts across the filtered month" do
    sign_in_as(role_key: "admin")
    ready_client = Client.create!(name: "Riverside Family Dental #{SecureRandom.hex(4)}", onboarding_status: "active")
    failed_client = Client.create!(name: "Evergreen Dental Studio #{SecureRandom.hex(4)}", onboarding_status: "active")
    ready_client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generation_status: "ready", generated_at: Time.current)
    failed_client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generation_status: "failed")

    get report_log_path(month: "2026-06")

    assert_response :success
    assert_select "a", text: /Ready 1/
    assert_select "a", text: /Failed 1/
  end
end
