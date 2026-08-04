require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get clients_path

    assert_redirected_to login_path
  end

  test "index lists real clients and supports search and status filters" do
    sign_in_as(role: "admin")
    Client.create!(name: "Bright Smiles Dental", onboarding_status: "active")
    Client.create!(name: "Lakeside Orthodontics", onboarding_status: "pending")

    get clients_path
    assert_response :success
    assert_select "p", text: "Bright Smiles Dental"
    assert_select "p", text: "Lakeside Orthodontics"

    get clients_path, params: { status: "pending" }
    assert_response :success
    assert_select "p", text: "Lakeside Orthodontics"
    assert_select "p", text: "Bright Smiles Dental", count: 0

    get clients_path, params: { q: "Bright" }
    assert_response :success
    assert_select "p", text: "Bright Smiles Dental"
    assert_select "p", text: "Lakeside Orthodontics", count: 0
  end

  test "show finds the real client requested, with no fallback to a different one" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Real Practice", onboarding_status: "active")

    get client_path(client)

    assert_response :success
    assert_select "h1", text: "Real Practice"
  end

  test "show renders the empty states for a client with no reports" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Fresh Practice", onboarding_status: "active")

    get client_path(client)

    assert_response :success
    assert_select "p", text: "No report generated yet."
    assert_select "p", text: "Not generated yet."
  end

  test "show renders the latest report snapshot and secure link for a client with a generated report" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Established Practice", onboarding_status: "active")
    report = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generated_at: Time.current)
    report.create_report_traffic!(total_visits: 3482, appointments_booked: 61, ghl_data_status: "connected")

    get client_path(client)

    assert_response :success
    assert_select "h2", text: "Latest report snapshot"
    assert_select "input[readonly][value=?]", public_report_path(report.access_token)
  end

  test "show 404s for an id that doesn't exist, instead of silently substituting another client" do
    sign_in_as(role: "admin")
    Client.create!(name: "Some Other Practice", onboarding_status: "active")

    get client_path(SecureRandom.uuid)

    assert_response :not_found
  end

  private

  def sign_in_as(role:)
    admin = AdminUser.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
    post login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end
