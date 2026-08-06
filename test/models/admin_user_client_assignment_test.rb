require "test_helper"

class AdminUserClientAssignmentTest < ActiveSupport::TestCase
  test "assigning a client to an admin_user makes it appear in assigned_clients" do
    admin_user = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))
    client = Client.create!(name: "Assigned Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    admin_user.admin_user_client_assignments.create!(client: client)

    assert_includes admin_user.reload.assigned_clients, client
  end

  test "the same client cannot be assigned twice to the same admin_user" do
    admin_user = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))
    client = Client.create!(name: "Assigned Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    admin_user.admin_user_client_assignments.create!(client: client)

    duplicate = admin_user.admin_user_client_assignments.build(client: client)

    assert_not duplicate.valid?
  end
end
