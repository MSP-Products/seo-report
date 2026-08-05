require "test_helper"

class GhlOauthClientTest < ActiveSupport::TestCase
  TOKEN_URL = "https://services.leadconnectorhq.com/oauth/token"
  LOCATION_TOKEN_URL = "https://services.leadconnectorhq.com/oauth/locationToken"

  test "authorize_url includes the redirect_uri, scope, and state" do
    url = GhlOauthClient.new.authorize_url(redirect_uri: "http://localhost:3000/connections/ghl/callback", state: "abc123")

    assert_match %r{\Ahttps://marketplace\.gohighlevel\.com/oauth/chooselocation\?}, url
    assert_includes url, "redirect_uri=http%3A%2F%2Flocalhost%3A3000%2Fconnections%2Fghl%2Fcallback"
    assert_includes url, "state=abc123"
    assert_includes url, "response_type=code"
  end

  test "exchange_code! persists access_token, refresh_token, expires_at, and company_id" do
    stub_request(:post, TOKEN_URL)
      .with(body: hash_including("grant_type" => "authorization_code", "code" => "auth-code-123"))
      .to_return(status: 200, body: {
        access_token: "agency-access-token", refresh_token: "agency-refresh-token",
        expires_in: 86400, companyId: "company-abc"
      }.to_json)

    GhlOauthClient.new.exchange_code!(code: "auth-code-123", redirect_uri: "http://localhost:3000/connections/ghl/callback")

    connection = AgencyConnection.find_by!(service: "ghl")
    assert_equal "agency-access-token", connection.credentials["access_token"]
    assert_equal "agency-refresh-token", connection.credentials["refresh_token"]
    assert_equal "company-abc", connection.credentials["company_id"]
    assert_equal "active", connection.credential_status
    assert connection.expires_at > 23.hours.from_now
    assert connection.last_verified_at.present?
  end

  test "exchange_code! wraps a failure as a short, generic AuthorizationError" do
    stub_request(:post, TOKEN_URL).to_return(status: 400, body: { error: "invalid_grant", error_description: "internal-detail-should-not-leak" }.to_json)

    error = assert_raises(GhlOauthClient::AuthorizationError) do
      GhlOauthClient.new.exchange_code!(code: "bad-code", redirect_uri: "http://localhost:3000/connections/ghl/callback")
    end

    assert_equal "could not complete authorization", error.message
    assert_no_match(/internal-detail-should-not-leak/, error.message)
  end

  test "location_access_token! refreshes a stale agency token, persisting the NEW rotated refresh_token" do
    connection = AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "stale-access-token", refresh_token: "old-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 1.minute.ago)

    stub_request(:post, TOKEN_URL)
      .with(body: hash_including("grant_type" => "refresh_token", "refresh_token" => "old-refresh-token"))
      .to_return(status: 200, body: { access_token: "fresh-access-token", refresh_token: "new-refresh-token", expires_in: 86400 }.to_json)

    stub_request(:post, LOCATION_TOKEN_URL)
      .with(body: hash_including("companyId" => "company-abc", "locationId" => "location-1"))
      .to_return(status: 200, body: { access_token: "location-token-xyz" }.to_json)

    token = GhlOauthClient.new.location_access_token!(location_id: "location-1")

    assert_equal "location-token-xyz", token
    connection.reload
    assert_equal "new-refresh-token", connection.credentials["refresh_token"]
    refute_equal "old-refresh-token", connection.credentials["refresh_token"]
  end

  test "location_access_token! does not refresh a still-valid agency token" do
    AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "valid-access-token", refresh_token: "unused-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 2.hours.from_now)

    stub_request(:post, LOCATION_TOKEN_URL).to_return(status: 200, body: { access_token: "location-token-xyz" }.to_json)

    GhlOauthClient.new.location_access_token!(location_id: "location-1")

    assert_not_requested :post, TOKEN_URL
  end

  test "agency_access_token! refreshes a stale token and returns the raw agency access_token" do
    connection = AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "stale-access-token", refresh_token: "old-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 1.minute.ago)

    stub_request(:post, TOKEN_URL)
      .with(body: hash_including("grant_type" => "refresh_token", "refresh_token" => "old-refresh-token"))
      .to_return(status: 200, body: { access_token: "fresh-access-token", refresh_token: "new-refresh-token", expires_in: 86400 }.to_json)

    token = GhlOauthClient.new.agency_access_token!

    assert_equal "fresh-access-token", token
    assert_not_requested :post, LOCATION_TOKEN_URL
    connection.reload
    assert_equal "new-refresh-token", connection.credentials["refresh_token"]
  end

  test "agency_access_token! does not refresh a still-valid token" do
    AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "valid-access-token", refresh_token: "unused-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 2.hours.from_now)

    token = GhlOauthClient.new.agency_access_token!

    assert_equal "valid-access-token", token
    assert_not_requested :post, TOKEN_URL
  end

  test "a refresh failure marks the connection expired and re-raises" do
    AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "stale", refresh_token: "bad-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 1.minute.ago)

    stub_request(:post, TOKEN_URL).to_return(status: 401, body: { error: "invalid_grant" }.to_json)

    assert_raises(Faraday::Error) do
      GhlOauthClient.new.location_access_token!(location_id: "location-1")
    end

    assert_equal "expired", AgencyConnection.find_by!(service: "ghl").credential_status
  end

  test "a location-token-mint HTTP failure propagates unwrapped, without touching credential_status" do
    AgencyConnection.create!(service: "ghl", credential_status: "active", encrypted_credentials: {
      access_token: "valid-access-token", refresh_token: "unused-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 2.hours.from_now)

    stub_request(:post, LOCATION_TOKEN_URL).to_return(status: 500)

    assert_raises(Faraday::Error) do
      GhlOauthClient.new.location_access_token!(location_id: "location-1")
    end

    assert_equal "active", AgencyConnection.find_by!(service: "ghl").credential_status
  end

  test "raises without any HTTP call when never connected via OAuth" do
    AgencyConnection.create!(service: "ghl", encrypted_credentials: "{}")

    assert_raises(GhlOauthClient::NotConnectedError) do
      GhlOauthClient.new.location_access_token!(location_id: "location-1")
    end

    assert_not_requested :post, TOKEN_URL
    assert_not_requested :post, LOCATION_TOKEN_URL
  end

  test "raises without minting a location token when company_id is missing" do
    AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "valid-access-token", refresh_token: "unused-refresh-token"
    }.to_json, expires_at: 2.hours.from_now)

    assert_raises(GhlOauthClient::NotConnectedError) do
      GhlOauthClient.new.location_access_token!(location_id: "location-1")
    end

    assert_not_requested :post, LOCATION_TOKEN_URL
  end

  test "refresh_if_stale! refreshes a stale agency token" do
    connection = AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "stale-access-token", refresh_token: "old-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 1.minute.ago)

    stub_request(:post, TOKEN_URL)
      .with(body: hash_including("grant_type" => "refresh_token", "refresh_token" => "old-refresh-token"))
      .to_return(status: 200, body: { access_token: "fresh-access-token", refresh_token: "new-refresh-token", expires_in: 86400 }.to_json)

    GhlOauthClient.new.refresh_if_stale!

    assert_equal "new-refresh-token", connection.reload.credentials["refresh_token"]
  end

  test "refresh_if_stale! does nothing to a still-valid agency token" do
    AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "valid-access-token", refresh_token: "unused-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 2.hours.from_now)

    GhlOauthClient.new.refresh_if_stale!

    assert_not_requested :post, TOKEN_URL
  end

  test "refresh_if_stale! is a no-op, not an error, when never connected via OAuth" do
    AgencyConnection.create!(service: "ghl", encrypted_credentials: "{}")

    GhlOauthClient.new.refresh_if_stale!

    assert_not_requested :post, TOKEN_URL
  end

  test "refresh_if_stale! is a no-op when there is no AgencyConnection row at all" do
    GhlOauthClient.new.refresh_if_stale!

    assert_not_requested :post, TOKEN_URL
  end
end
