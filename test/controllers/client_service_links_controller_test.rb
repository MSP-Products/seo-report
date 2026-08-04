require "test_helper"

class ClientServiceLinksControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    get client_data_sources_path(client)

    assert_redirected_to login_path
  end

  test "renders the client's real linked services" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")
    client.client_service_links.create!(service: "hubspot", external_id: "company-42")

    get client_data_sources_path(client)

    assert_response :success
    assert_select "span", text: "HubSpot"
    assert_select "td", text: "company-42"
  end

  test "index shows all five services even when only one is linked" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")
    client.client_service_links.create!(service: "hubspot", external_id: "company-42")

    get client_data_sources_path(client)

    assert_response :success
    assert_select "span", text: "HubSpot"
    assert_select "span", text: "GoHighLevel"
    assert_select "span", text: "Yext"
    assert_select "span", text: "SEMrush"
    assert_select "span", text: "Google Analytics"
    assert_select "span", text: "Not linked", minimum: 1
  end

  test "support role can view but not edit or update a service link" do
    sign_in_as(role: "support")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    get edit_client_data_source_path(client, "hubspot")
    assert_redirected_to root_path

    patch client_data_source_path(client, "hubspot"), params: { client_service_link: { external_id: "hijacked" } }
    assert_nil client.client_service_links.find_by(service: "hubspot")
  end

  test "admin can set a service link's external_id" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    get edit_client_data_source_path(client, "hubspot")
    assert_response :success

    patch client_data_source_path(client, "hubspot"), params: { client_service_link: { external_id: "company-99" } }

    assert_redirected_to client_data_sources_path(client)
    assert_equal "company-99", client.client_service_links.find_by(service: "hubspot").external_id
  end

  test "an unknown service redirects with an alert" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    get edit_client_data_source_path(client, "not-a-real-service")

    assert_redirected_to client_data_sources_path(client)
  end

  private

  def sign_in_as(role:)
    admin = AdminUser.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
    post login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end
