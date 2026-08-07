require "test_helper"

class TeamMemberInviterTest < ActiveSupport::TestCase
  test "creates the account with a generated password and delivers it once" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    admin_user = TeamMemberInviter.new(
      attrs: { email: "new-#{SecureRandom.hex(4)}@example.com", first_name: "New", last_name: "Hire",
        role_id: Role.find_by!(key: "account_manager").id },
      actor: actor
    ).call

    assert admin_user.persisted?
    assert_not_nil admin_user.generated_password
    assert admin_user.authenticate(admin_user.generated_password)
  end

  test "a Super Admin can invite someone as Super Admin" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)

    admin_user = TeamMemberInviter.new(
      attrs: { email: "new-#{SecureRandom.hex(4)}@example.com", role_id: Role.super_admin.id },
      actor: actor
    ).call

    assert admin_user.persisted?
    assert_equal Role.super_admin.id, admin_user.role_id
  end

  test "an Admin cannot invite someone as Super Admin" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    admin_user = TeamMemberInviter.new(
      attrs: { email: "new-#{SecureRandom.hex(4)}@example.com", role_id: Role.super_admin.id },
      actor: actor
    ).call

    assert_not admin_user.persisted?
    assert_includes admin_user.errors[:role_id], "can only be assigned by a Super Admin"
  end

  test "does not persist or deliver anything when validation fails" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    admin_user = TeamMemberInviter.new(
      attrs: { email: "", role_id: Role.find_by!(key: "account_manager").id },
      actor: actor
    ).call

    assert_not admin_user.persisted?
    assert admin_user.errors[:email].any?
  end
end
