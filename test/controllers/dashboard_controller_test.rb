require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get dashboard_path

    assert_redirected_to login_path
  end

  test "renders real client and connection data" do
    sign_in_as(role_key: "admin")
    Client.create!(name: "Bright Smile Dental #{SecureRandom.hex(4)}", onboarding_status: "active")

    get dashboard_path

    assert_response :success
    assert_select "h1", text: "Dashboard"
    assert_match(/SEMrush/, response.body)
  end

  test "shows the generation run table once a report exists for the cycle" do
    sign_in_as(role_key: "admin")
    client = Client.create!(name: "Woodside Dental Care #{SecureRandom.hex(4)}", onboarding_status: "active")
    month = Date.current.beginning_of_month - 1.month
    client.monthly_reports.create!(report_month: month, generation_status: "ready", generated_at: Time.current)

    get dashboard_path

    assert_response :success
    assert_select "p", text: client.name
  end

  test "shows an active client with no report yet as not started, instead of omitting it" do
    sign_in_as(role_key: "admin")
    client = Client.create!(name: "Bayview Family Dentistry #{SecureRandom.hex(4)}", onboarding_status: "active")

    get dashboard_path

    assert_response :success
    assert_select "p", text: client.name
    assert_match(/Not started/, response.body)
  end

  test "shows the real held reason next to a held send, not a bare badge" do
    sign_in_as(role_key: "admin")
    client = Client.create!(name: "Cedar Park Family Dentistry #{SecureRandom.hex(4)}", onboarding_status: "active")
    month = Date.current.beginning_of_month - 1.month
    report = client.monthly_reports.create!(report_month: month, generation_status: "ready", generated_at: Time.current)
    report.send_logs.create!(status: "held", attempted_at: Time.current, error_message: "HubSpot token rejected")

    get dashboard_path

    assert_response :success
    assert_match(/Held — HubSpot token rejected/, response.body)
  end

  test "root routes to the dashboard for a signed-in admin" do
    sign_in_as(role_key: "admin")

    get root_path

    assert_response :success
    assert_select "h1", text: "Dashboard"
  end
end
