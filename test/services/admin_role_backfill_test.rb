require "test_helper"

class AdminRoleBackfillTest < ActiveSupport::TestCase
  test "maps a legacy admin role to Super Admin and stamps last_active_at" do
    legacy = build_legacy_admin_user(role: "admin")

    AdminRoleBackfill.new.call

    legacy.reload
    assert_equal Role.super_admin.id, legacy.role_id
    assert_not_nil legacy.last_active_at
  end

  test "maps a legacy support role to Account Manager" do
    legacy = build_legacy_admin_user(role: "support")

    AdminRoleBackfill.new.call

    assert_equal Role.find_by!(key: "account_manager").id, legacy.reload.role_id
  end

  test "does not touch a row that already has a role_id" do
    already_migrated = AdminUser.create!(email: "migrated-#{SecureRandom.hex(4)}@example.com",
      password: "password123", role: Role.find_by!(key: "admin"))
    already_migrated.update_column(:last_active_at, nil)

    AdminRoleBackfill.new.call

    assert_nil already_migrated.reload.last_active_at
  end

  test "raises on an unrecognized legacy role value, rather than silently skipping it" do
    build_legacy_admin_user(role: "some_future_role")

    assert_raises(RuntimeError) { AdminRoleBackfill.new.call }
  end

  test "is safe to run twice" do
    legacy = build_legacy_admin_user(role: "admin")

    AdminRoleBackfill.new.call
    AdminRoleBackfill.new.call

    assert_equal Role.super_admin.id, legacy.reload.role_id
  end

  private

  def build_legacy_admin_user(role:)
    admin_user = AdminUser.new(email: "legacy-#{SecureRandom.hex(4)}@example.com")
    admin_user.password = "password123"
    admin_user[:role] = role
    admin_user.save!(validate: false)
    admin_user
  end
end
