require "test_helper"

class AdminUserPermissionTest < ActiveSupport::TestCase
  test "a permission_key cannot be overridden twice for the same admin_user" do
    admin_user = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))
    admin_user.admin_user_permissions.create!(permission_key: "connections_edit", granted: true)

    duplicate = admin_user.admin_user_permissions.build(permission_key: "connections_edit", granted: false)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:permission_key], "has already been taken"
  end

  test "the same permission_key can be overridden for two different admin_users" do
    role = Role.find_by!(key: "account_manager")
    first = AdminUser.create!(email: "first-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)
    second = AdminUser.create!(email: "second-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)

    first.admin_user_permissions.create!(permission_key: "connections_edit", granted: true)

    assert second.admin_user_permissions.create(permission_key: "connections_edit", granted: true).persisted?
  end
end
