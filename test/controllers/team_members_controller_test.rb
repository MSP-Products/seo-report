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
end
