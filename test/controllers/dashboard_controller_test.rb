require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get dashboard_path

    assert_redirected_to login_path
  end

  test "shows real counts for active clients" do
    sign_in_as(role: "admin")
    month = MonthlyReport.reporting_month
    client = Client.create!(name: "Real Practice", onboarding_status: "active")
    client.monthly_reports.create!(report_month: month, generated_at: Time.current)
    Client.create!(name: "Pending Practice", onboarding_status: "pending")

    get dashboard_path

    assert_response :success
    assert_select "p", text: "Real Practice"
    assert_select "p", text: "1 pending onboarding"
  end

  private

  def sign_in_as(role:)
    admin = AdminUser.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
    post login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end
