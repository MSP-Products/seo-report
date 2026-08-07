require "test_helper"

class TeamMemberUpdaterTest < ActiveSupport::TestCase
  test "updates the member's details" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      first_name: "Old", role: Role.find_by!(key: "account_manager"))

    result = TeamMemberUpdater.new(admin_user: member, attrs: { first_name: "New" }, actor: actor).call

    assert result.errors.empty?
    assert_equal "New", member.reload.first_name
  end

  test "a Super Admin can promote someone to Super Admin" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    result = TeamMemberUpdater.new(admin_user: member, attrs: { role_id: Role.super_admin.id }, actor: actor).call

    assert result.errors.empty?
    assert_equal Role.super_admin, member.reload.role
  end

  test "an Admin cannot promote someone to Super Admin" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    result = TeamMemberUpdater.new(admin_user: member, attrs: { role_id: Role.super_admin.id }, actor: actor).call

    assert_includes result.errors[:role_id], "can only be assigned by a Super Admin"
    assert_not_equal Role.super_admin, member.reload.role
  end

  test "a validation failure leaves the member's role unchanged" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))

    result = TeamMemberUpdater.new(admin_user: member, attrs: { email: "" }, actor: actor).call

    assert result.errors[:email].any?
    assert_equal "account_manager", member.reload.role.key
  end

  test "the last Super Admin's role cannot be changed away" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    last = AdminUser.create!(email: "last-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)

    result = TeamMemberUpdater.new(admin_user: last, attrs: { role_id: Role.find_by!(key: "admin").id },
      actor: actor).call

    assert_includes result.errors[:role_id], "can't be changed away from Super Admin — this is the last one."
  end
end
