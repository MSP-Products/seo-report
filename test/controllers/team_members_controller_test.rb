require "test_helper"

class TeamMembersControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get team_members_path

    assert_redirected_to login_path
  end

  test "a Super Admin can view the team list" do
    sign_in_as(role_key: "super_admin")

    get team_members_path

    assert_response :success
    assert_select "h1", text: "Team"
  end

  test "an Admin can view the team list" do
    sign_in_as(role_key: "admin")

    get team_members_path

    assert_response :success
  end

  test "an Account Manager is redirected away from the team list" do
    sign_in_as(role_key: "account_manager")

    get team_members_path

    assert_redirected_to root_path
  end

  test "lists every kept team member with their role" do
    sign_in_as(role_key: "admin")
    AdminUser.create!(email: "dana-#{SecureRandom.hex(4)}@example.com", password: "password123",
      first_name: "Dana", last_name: "Reyes", role: Role.find_by!(key: "account_manager"))

    get team_members_path

    assert_select "p", text: "Dana Reyes"
    assert_select "span", text: "Account Manager"
  end

  test "does not list a discarded team member" do
    sign_in_as(role_key: "admin")
    removed = AdminUser.create!(email: "gone-#{SecureRandom.hex(4)}@example.com", password: "password123",
      first_name: "Gone", last_name: "Away", role: Role.find_by!(key: "admin"))
    removed.discard

    get team_members_path

    assert_select "p", text: "Gone Away", count: 0
  end

  test "shows the current viewer's own row as You" do
    admin = sign_in_as(role_key: "admin")

    get team_members_path

    assert_select "p", text: admin.email
    assert_select "span", text: "You"
  end

  test "shows a role summary card listing its permissions" do
    sign_in_as(role_key: "admin")

    get team_members_path

    assert_select "span", text: "Super Admin"
    assert_select "li", text: "Delete clients"
  end

  test "an Account Manager cannot reach the invite form" do
    sign_in_as(role_key: "account_manager")

    get new_team_member_path

    assert_redirected_to root_path
  end

  test "an Admin can invite a new member and sees the generated password once" do
    sign_in_as(role_key: "admin")
    account_manager_role = Role.find_by!(key: "account_manager")

    post team_members_path, params: { admin_user: { email: "new-hire@example.com", first_name: "New",
      last_name: "Hire", role_id: account_manager_role.id } }

    assert_response :success
    assert_select "h1", text: "New Hire was invited"
    new_member = AdminUser.find_by!(email: "new-hire@example.com")
    assert_equal account_manager_role, new_member.role
    password = css_select("#generated-password").first.text
    assert new_member.authenticate(password)
  end

  test "the generated password never reappears once the invite screen is left" do
    sign_in_as(role_key: "admin")
    post team_members_path, params: { admin_user: { email: "new-hire2@example.com",
      role_id: Role.find_by!(key: "account_manager").id } }
    password = css_select("#generated-password").first.text

    get team_members_path

    assert_no_match(/#{Regexp.escape(password)}/, response.body)
  end

  test "an Admin cannot invite someone as Super Admin" do
    sign_in_as(role_key: "admin")

    post team_members_path, params: { admin_user: { email: "wannabe@example.com", role_id: Role.super_admin.id } }

    assert_response :unprocessable_entity
    assert_nil AdminUser.find_by(email: "wannabe@example.com")
  end

  test "a Super Admin can invite someone as Super Admin" do
    sign_in_as(role_key: "super_admin")

    post team_members_path, params: { admin_user: { email: "future-super@example.com", role_id: Role.super_admin.id } }

    assert_response :success
    assert_equal Role.super_admin, AdminUser.find_by!(email: "future-super@example.com").role
  end

  test "the invite form only offers assignable roles to a plain Admin" do
    sign_in_as(role_key: "admin")

    get new_team_member_path

    assert_select "option", text: "Super Admin", count: 0
    assert_select "option", text: "Admin"
  end

  test "an Account Manager cannot reach the manage form" do
    sign_in_as(role_key: "account_manager")
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    get edit_team_member_path(member)

    assert_redirected_to root_path
  end

  test "an Admin can update a member's name" do
    sign_in_as(role_key: "admin")
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      first_name: "Old", role: Role.find_by!(key: "account_manager"))

    patch team_member_path(member), params: { admin_user: { first_name: "New" } }

    assert_redirected_to team_members_path
    assert_equal "New", member.reload.first_name
  end

  test "an Admin cannot promote a member to Super Admin through the manage form" do
    sign_in_as(role_key: "admin")
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    patch team_member_path(member), params: { admin_user: { role_id: Role.super_admin.id } }

    assert_response :unprocessable_entity
    assert_not_equal Role.super_admin, member.reload.role
  end

  test "Manage link only appears for a viewer who can edit members" do
    sign_in_as(role_key: "admin")
    AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))

    get team_members_path

    assert_select "a", text: "Manage", minimum: 1
  end

  test "an Account Manager cannot remove a team member" do
    sign_in_as(role_key: "account_manager")
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "admin"))

    delete team_member_path(member)

    assert_redirected_to root_path
    assert_not member.reload.discarded?
  end

  test "an Admin can remove a team member, who then disappears from the list" do
    sign_in_as(role_key: "admin")
    member = AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      first_name: "Gone", last_name: "Away", role: Role.find_by!(key: "account_manager"))

    delete team_member_path(member)

    assert_redirected_to team_members_path
    assert member.reload.discarded?
    follow_redirect!
    assert_select "p", text: "Gone Away", count: 0
  end

  test "the last Super Admin cannot be removed" do
    sign_in_as(role_key: "admin")
    last = AdminUser.create!(email: "last-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)

    delete team_member_path(last)

    assert_redirected_to team_members_path
    assert_not last.reload.discarded?
    follow_redirect!
    assert_match(/Can&#39;t remove the last Super Admin/, response.body)
  end

  test "a Super Admin becomes removable once a second one exists" do
    sign_in_as(role_key: "admin")
    first_super_admin = AdminUser.create!(email: "first-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)
    AdminUser.create!(email: "second-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.super_admin)

    delete team_member_path(first_super_admin)

    assert first_super_admin.reload.discarded?
  end

  test "the Remove button only appears for a viewer who can remove members" do
    sign_in_as(role_key: "admin")
    AdminUser.create!(email: "member-#{SecureRandom.hex(4)}@example.com", password: "password123",
      role: Role.find_by!(key: "account_manager"))

    get team_members_path

    assert_select "button", text: "Remove", minimum: 1
  end
end
