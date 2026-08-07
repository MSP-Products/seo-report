# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = AdminUser.create!(
      email: "admin@example.com",
      password: "password123",
      role: Role.find_by!(key: "admin")
    )
  end

  test "should get new login page" do
    get login_url
    assert_response :success
    assert_select "h1", "My Social Practice"
    assert_select "p", "SEO Reports Admin"
  end

  test "should authenticate with valid credentials" do
    post login_url, params: { email: "admin@example.com", password: "password123" }
    assert_redirected_to root_url
    assert_equal @admin_user.id, session[:admin_user_id]
  end

  test "should fail authentication with invalid password" do
    post login_url, params: { email: "admin@example.com", password: "wrongpassword" }
    assert_response :unprocessable_entity
    assert_select "#alert-error", text: /Incorrect email or password/
  end

  test "should log out admin" do
    post login_url, params: { email: "admin@example.com", password: "password123" }
    delete logout_url
    assert_redirected_to login_url
    assert_nil session[:admin_user_id]
  end
end
