require "test_helper"

class AdminUserTest < ActiveSupport::TestCase
  test "admin? is true for Super Admin and Admin, false for Account Manager" do
    assert AdminUser.new(role: Role.find_by!(key: "super_admin")).admin?
    assert AdminUser.new(role: Role.find_by!(key: "admin")).admin?
    assert_not AdminUser.new(role: Role.find_by!(key: "account_manager")).admin?
  end

  test "support? is true only for Account Manager" do
    assert AdminUser.new(role: Role.find_by!(key: "account_manager")).support?
    assert_not AdminUser.new(role: Role.find_by!(key: "admin")).support?
  end

  test "can? reflects the role's default permissions with no overrides" do
    account_manager = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))

    assert account_manager.can?(:clients_view)
    assert_not account_manager.can?(:connections_edit)
  end

  test "an override can grant a permission beyond the role's defaults" do
    account_manager = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))
    account_manager.admin_user_permissions.create!(permission_key: "connections_edit", granted: true)

    assert account_manager.can?(:connections_edit)
  end

  test "an override can revoke a permission the role would otherwise grant" do
    admin = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    admin.admin_user_permissions.create!(permission_key: "clients_view", granted: false)

    assert_not admin.can?(:clients_view)
  end

  test "display_name falls back to email when no name is set" do
    admin_user = AdminUser.new(email: "nameless@example.com")

    assert_equal "nameless@example.com", admin_user.display_name
  end

  test "display_name joins first and last name when present" do
    admin_user = AdminUser.new(email: "member@example.com", first_name: "Dana", last_name: "Reyes")

    assert_equal "Dana Reyes", admin_user.display_name
  end

  test "invited? is true until last_active_at is set" do
    admin_user = AdminUser.new
    assert admin_user.invited?

    admin_user.last_active_at = Time.current
    assert_not admin_user.invited?
  end

  test "the last Super Admin cannot be discarded" do
    last = AdminUser.create!(email: "last-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)

    assert_not last.discard
    assert_includes last.errors[:base], "Can't remove the last Super Admin."
    assert_not last.reload.discarded?
  end

  test "the last Super Admin's role cannot be changed away from Super Admin" do
    last = AdminUser.create!(email: "last-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)

    last.role = Role.find_by!(key: "admin")

    assert_not last.save
    assert_includes last.errors[:role_id], "can't be changed away from Super Admin — this is the last one."
  end

  test "a Super Admin becomes removable once a second one exists" do
    first = AdminUser.create!(email: "first-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)
    AdminUser.create!(email: "second-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)

    assert first.discard
  end

  test "a Super Admin's role can change once a second Super Admin exists" do
    first = AdminUser.create!(email: "first-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)
    AdminUser.create!(email: "second-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)

    first.role = Role.find_by!(key: "admin")

    assert first.save
  end

  test "discarding a non-last Super Admin does not affect a plain Admin" do
    admin = AdminUser.create!(email: "admin-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    assert admin.discard
  end

  test "kept excludes discarded admin_users" do
    admin_user = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    other = AdminUser.create!(email: "other-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    admin_user.discard

    assert_not_includes AdminUser.kept, admin_user
    assert_includes AdminUser.kept, other
  end

  test "touch_last_active sets last_active_at without firing validations" do
    admin_user = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    admin_user.touch_last_active

    assert_not_nil admin_user.reload.last_active_at
  end

  test "touch_last_active does not re-write within the throttle window" do
    admin_user = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    admin_user.touch_last_active
    first_touch = admin_user.reload.last_active_at

    admin_user.touch_last_active

    assert_equal first_touch, admin_user.reload.last_active_at
  end
end
