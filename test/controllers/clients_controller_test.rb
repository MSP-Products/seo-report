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

  test "new renders the add-practice form" do
    sign_in_as(role: "admin")

    get new_client_path

    assert_response :success
    assert_select "h1", text: "Add practice"
  end

  test "create with valid params persists the client and its service links, then redirects" do
    sign_in_as(role: "admin")

    post clients_path, params: {
      client: { name: "New Practice", website_url: "https://newpractice.com" },
      service_links: { hubspot: "company-9" }
    }

    client = Client.find_by(name: "New Practice")
    assert client.present?
    assert_redirected_to client_path(client)
    assert_equal [ "hubspot" ], client.client_service_links.pluck(:service)
  end

  test "create with a blank name re-renders the form and persists nothing" do
    sign_in_as(role: "admin")

    post clients_path, params: { client: { name: "" } }

    assert_response :unprocessable_entity
    assert_select "h1", text: "Add practice"
    assert_nil Client.find_by(name: "")
  end

  test "edit renders the form pre-filled with the client's real values" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Existing Practice", onboarding_status: "active", website_url: "https://existing.com")

    get edit_client_path(client)

    assert_response :success
    assert_select "h1", text: "Edit practice"
    assert_select "input[name=?][value=?]", "client[name]", "Existing Practice"
  end

  test "update with valid params persists changes and redirects to the client" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Old Name", onboarding_status: "active")

    patch client_path(client), params: { client: { name: "New Name" }, service_links: { hubspot: "company-5" } }

    assert_redirected_to client_path(client)
    assert_equal "New Name", client.reload.name
    assert_equal "company-5", client.client_service_links.find_by(service: "hubspot").external_id
  end

  test "update with a blank name re-renders the form and leaves the record unchanged" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Old Name", onboarding_status: "active")

    patch client_path(client), params: { client: { name: "" } }

    assert_response :unprocessable_entity
    assert_select "h1", text: "Edit practice"
    assert_equal "Old Name", client.reload.name
  end

  test "support role is redirected away from edit and blocked from update" do
    sign_in_as(role: "support")
    client = Client.create!(name: "Old Name", onboarding_status: "active")

    get edit_client_path(client)
    assert_redirected_to root_path

    patch client_path(client), params: { client: { name: "Hijacked" } }
    assert_equal "Old Name", client.reload.name
  end

  private

  def sign_in_as(role:)
    admin = AdminUser.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
    post login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end
