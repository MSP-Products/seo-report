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

    assert_includes result.errors[:role_id], "can only be changed by a Super Admin"
    assert_not_equal Role.super_admin, member.reload.role
  end

  test "an Admin cannot demote a Super Admin, even when a second Super Admin exists" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    AdminUser.create!(email: "other-super-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)

    result = TeamMemberUpdater.new(admin_user: member, attrs: { role_id: Role.find_by!(key: "admin").id },
      actor: actor).call

    assert_includes result.errors[:role_id], "can only be changed by a Super Admin"
    assert_equal Role.super_admin, member.reload.role
  end

  test "a Super Admin can demote another Super Admin when a second one exists" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com",
      password: "password123", role: Role.super_admin)

    result = TeamMemberUpdater.new(admin_user: member, attrs: { role_id: Role.find_by!(key: "admin").id },
      actor: actor).call

    assert result.errors.empty?
    assert_equal Role.find_by!(key: "admin"), member.reload.role
  end

  test "checking a permission the role already grants stores no override" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    TeamMemberUpdater.new(admin_user: member, attrs: {}, actor: actor,
      permission_overrides: { "clients_view" => "1" }).call

    assert_empty member.admin_user_permissions.where(permission_key: "clients_view")
  end

  test "unchecking a permission the role grants by default stores a revoke override" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    TeamMemberUpdater.new(admin_user: member, attrs: {}, actor: actor,
      permission_overrides: { "clients_view" => "0" }).call

    assert_not member.reload.can?(:clients_view)
  end

  test "checking a permission the role does not grant stores a grant override" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))

    TeamMemberUpdater.new(admin_user: member, attrs: {}, actor: actor,
      permission_overrides: { "connections_edit" => "1" }).call

    assert member.reload.can?(:connections_edit)
  end

  test "re-matching the role default after an override removes the override row" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member.admin_user_permissions.create!(permission_key: "clients_view", granted: false)

    TeamMemberUpdater.new(admin_user: member, attrs: {}, actor: actor,
      permission_overrides: { "clients_view" => "1" }).call

    assert_empty member.admin_user_permissions.where(permission_key: "clients_view")
    assert member.reload.can?(:clients_view)
  end

  test "an unrecognized permission key in the overrides hash is ignored" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    result = TeamMemberUpdater.new(admin_user: member, attrs: {}, actor: actor,
      permission_overrides: { "not_a_real_permission" => "1" }).call

    assert result.errors.empty?
  end

  test "assigns clients to an Account Manager" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))
    client = Client.create!(name: "Assignable Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    TeamMemberUpdater.new(admin_user: member, attrs: {}, actor: actor, client_ids: [ client.id ]).call

    assert_includes member.reload.assigned_clients, client
  end

  test "an empty client_ids array clears existing assignments" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))
    client = Client.create!(name: "Assignable Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    member.admin_user_client_assignments.create!(client: client)

    TeamMemberUpdater.new(admin_user: member, attrs: {}, actor: actor, client_ids: []).call

    assert_empty member.reload.assigned_clients
  end

  test "client_ids: nil leaves existing assignments untouched" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))
    client = Client.create!(name: "Assignable Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    member.admin_user_client_assignments.create!(client: client)

    TeamMemberUpdater.new(admin_user: member, attrs: { first_name: "Updated" }, actor: actor, client_ids: nil).call

    assert_includes member.reload.assigned_clients, client
  end

  test "a validation failure does not touch permission overrides or client assignments" do
    actor = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))

    result = TeamMemberUpdater.new(admin_user: member, attrs: { email: "" }, actor: actor,
      permission_overrides: { "connections_edit" => "1" }).call

    assert result.errors[:email].any?
    assert_not member.reload.can?(:connections_edit)
  end

  test "the last Super Admin's role cannot be changed away, even by a Super Admin actor" do
    created = AdminUser.create!(email: "actor-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)
    actor = AdminUser.find(created.id)
    last = AdminUser.find(created.id)

    result = TeamMemberUpdater.new(admin_user: last, attrs: { role_id: Role.find_by!(key: "admin").id },
      actor: actor).call

    assert_includes result.errors[:role_id], "can't be changed away from Super Admin — this is the last one."
  end
end
