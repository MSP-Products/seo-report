require "test_helper"

class ConnectionsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get connections_path

    assert_redirected_to login_path
  end

  test "index lists all five services, including ones never configured" do
    sign_in_as(role: "admin")

    get connections_path

    assert_response :success
    assert_select "p", text: "HubSpot"
    assert_select "p", text: "Not configured", minimum: 1
  end

  test "edit renders blank credential fields even when a value is already configured" do
    sign_in_as(role: "admin")
    AgencyConnection.create!(service: "hubspot", encrypted_credentials: { access_token: "super-secret-token" }.to_json)

    get edit_connection_path("hubspot")

    assert_response :success
    assert_no_match(/super-secret-token/, response.body)
  end

  test "update saves a new credential and does not echo it back" do
    sign_in_as(role: "admin")

    patch connection_path("hubspot"), params: { agency_connection: { access_token: "brand-new-token" } }
    follow_redirect!

    connection = AgencyConnection.find_by(service: "hubspot")
    assert_equal "brand-new-token", connection.credentials["access_token"]
    assert_no_match(/brand-new-token/, response.body)
  end

  test "a blank submitted value leaves the existing credential untouched" do
    sign_in_as(role: "admin")
    AgencyConnection.create!(service: "hubspot", encrypted_credentials: { access_token: "keep-me" }.to_json)

    patch connection_path("hubspot"), params: { agency_connection: { access_token: "" } }

    assert_equal "keep-me", AgencyConnection.find_by(service: "hubspot").credentials["access_token"]
  end

  test "support role can view but not edit or update" do
    sign_in_as(role: "support")
    AgencyConnection.create!(service: "hubspot", encrypted_credentials: { access_token: "keep-me" }.to_json)

    get connections_path
    assert_response :success

    get edit_connection_path("hubspot")
    assert_redirected_to root_path

    patch connection_path("hubspot"), params: { agency_connection: { access_token: "hijacked" } }
    assert_equal "keep-me", AgencyConnection.find_by(service: "hubspot").credentials["access_token"]
  end

  test "rejects an unknown service" do
    sign_in_as(role: "admin")

    get edit_connection_path("not-a-real-service")

    assert_redirected_to connections_path
  end

  test "google_analytics has no editable fields since it isn't live yet" do
    sign_in_as(role: "admin")

    get connections_path
    assert_select "a", text: "Edit", count: 4 # every service except google_analytics

    get edit_connection_path("google_analytics")
    assert_redirected_to connections_path
  end

  private

  def sign_in_as(role:)
    admin = AdminUser.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
    post login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end
