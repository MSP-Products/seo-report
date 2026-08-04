require "test_helper"

class MonthlyReportsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    get client_reports_path(client)

    assert_redirected_to login_path
  end

  test "renders the client's real report history" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")
    client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generated_at: Time.current)

    get client_reports_path(client)

    assert_response :success
    assert_select "td", text: "June 2026"
  end

  private

  def sign_in_as(role:)
    admin = AdminUser.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
    post login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end
