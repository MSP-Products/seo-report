require "test_helper"

module Connections
  class GhlOauthControllerTest < ActionDispatch::IntegrationTest
    TOKEN_URL = "https://services.leadconnectorhq.com/oauth/token"

    test "redirects to login when not authenticated" do
      get connections_ghl_authorize_path

      assert_redirected_to login_path
    end

    test "support role is blocked from both authorize and callback" do
      sign_in_as(role: "account_manager")

      get connections_ghl_authorize_path
      assert_redirected_to root_path

      get connections_ghl_callback_path, params: { code: "irrelevant", state: "irrelevant" }
      assert_redirected_to root_path
    end

    test "authorize redirects to GHL with a freshly generated state" do
      sign_in_as(role: "admin")

      get connections_ghl_authorize_path

      assert_response :redirect
      assert_match %r{\Ahttps://marketplace\.gohighlevel\.com/oauth/chooselocation\?}, response.location
      assert session[:ghl_oauth_state].present?
    end

    test "callback rejects a state that doesn't match the session, without attempting a token exchange" do
      sign_in_as(role: "admin")
      get connections_ghl_authorize_path

      get connections_ghl_callback_path, params: { code: "auth-code", state: "wrong-state" }

      assert_redirected_to edit_connection_path("ghl")
      assert_equal "GoHighLevel connection failed: state mismatch", flash[:alert]
      assert_not_requested :post, TOKEN_URL
    end

    test "callback with a matching state exchanges the code, persists tokens, and redirects with a notice" do
      sign_in_as(role: "admin")
      get connections_ghl_authorize_path
      state = session[:ghl_oauth_state]

      stub_request(:post, TOKEN_URL).to_return(status: 200, body: {
        access_token: "a", refresh_token: "b", expires_in: 86400, companyId: "c"
      }.to_json)

      get connections_ghl_callback_path, params: { code: "auth-code", state: state }

      assert_redirected_to edit_connection_path("ghl")
      assert_equal "Connected to GoHighLevel.", flash[:notice]
      assert_equal "active", AgencyConnection.find_by!(service: "ghl").credential_status
    end

    test "callback failure flashes a generic alert and never leaks the code or GHL's response body" do
      sign_in_as(role: "admin")
      get connections_ghl_authorize_path
      state = session[:ghl_oauth_state]

      stub_request(:post, TOKEN_URL).to_return(status: 400, body: { error: "invalid_grant", error_description: "leaked-detail" }.to_json)

      get connections_ghl_callback_path, params: { code: "bad-code", state: state }
      follow_redirect!

      assert_no_match(/leaked-detail/, response.body)
      assert_no_match(/bad-code/, response.body)
    end
  end
end
