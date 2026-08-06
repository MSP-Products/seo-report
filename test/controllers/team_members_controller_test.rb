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
end
