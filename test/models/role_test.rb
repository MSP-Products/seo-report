require "test_helper"

class RoleTest < ActiveSupport::TestCase
  test "key must be unique" do
    duplicate = Role.new(key: "admin", name: "Duplicate Admin")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "key and name are required" do
    role = Role.new

    assert_not role.valid?
    assert_includes role.errors[:key], "can't be blank"
    assert_includes role.errors[:name], "can't be blank"
  end

  test "super_admin finds the seeded Super Admin role" do
    assert_equal "super_admin", Role.super_admin.key
  end

  test "DEFAULT_PERMISSIONS grants Admin everything except role management and client deletion" do
    admin_permissions = Role::DEFAULT_PERMISSIONS.fetch("admin")

    assert_includes admin_permissions, "clients_edit"
    assert_not_includes admin_permissions, "clients_delete"
    assert_not_includes admin_permissions, "roles_manage"
  end

  test "DEFAULT_PERMISSIONS restricts Account Manager to viewing and generating reports" do
    account_manager_permissions = Role::DEFAULT_PERMISSIONS.fetch("account_manager")

    assert_equal %w[clients_view dashboard_view reports_view reports_generate].sort, account_manager_permissions.sort
  end

  test "cannot be destroyed while an admin_user still references it" do
    role = Role.create!(key: "temp_role_#{SecureRandom.hex(4)}", name: "Temp Role")
    AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123", role: role)

    assert_not role.destroy
    assert role.errors[:base].any?
    assert Role.exists?(role.id)
  end
end
