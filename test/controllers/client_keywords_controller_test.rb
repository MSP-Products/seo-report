require "test_helper"

class ClientKeywordsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    get client_keywords_path(client)

    assert_redirected_to login_path
  end

  test "renders the client's real tracked keywords" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")
    client.client_keywords.create!(keyword: "dentist near me", intent: "T")

    get client_keywords_path(client)

    assert_response :success
    assert_select "td", text: "dentist near me"
  end

  test "renders the current position and gain/drop for a ranked keyword" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")
    keyword = client.client_keywords.create!(keyword: "dentist near me", intent: "T", keyword_difficulty: 57)
    report = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generated_at: Time.current)
    report.report_keyword_rankings.create!(keyword: keyword, position: 4, previous_position: 6)

    get client_keywords_path(client)

    assert_response :success
    assert_select "td", text: /4/
    assert_select "span", text: "▲2"
  end

  private

  def sign_in_as(role:)
    admin = AdminUser.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
    post login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end
