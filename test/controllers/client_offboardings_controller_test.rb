require "test_helper"

class ClientOffboardingsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    post client_offboarding_path(client)

    assert_redirected_to login_path
  end

  test "support role is blocked from offboarding a client" do
    sign_in_as(role: "support")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    post client_offboarding_path(client)

    assert_equal "active", client.reload.onboarding_status
  end

  test "admin can offboard a client" do
    sign_in_as(role: "admin")
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    post client_offboarding_path(client)

    assert_redirected_to client_path(client)
    assert_equal "offboarded", client.reload.onboarding_status
  end

  private

  def sign_in_as(role:)
    admin = AdminUser.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
    post login_path, params: { email: admin.email, password: "password123" }
    admin
  end
end
