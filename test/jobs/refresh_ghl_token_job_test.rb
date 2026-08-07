require "test_helper"

class RefreshGhlTokenJobTest < ActiveJob::TestCase
  test "delegates to GhlOauthClient#refresh_if_stale!" do
    AgencyConnection.create!(service: "ghl", encrypted_credentials: {
      access_token: "stale-access-token", refresh_token: "old-refresh-token", company_id: "company-abc"
    }.to_json, expires_at: 1.minute.ago)

    stub_request(:post, "https://services.leadconnectorhq.com/oauth/token")
      .with(body: hash_including("grant_type" => "refresh_token", "refresh_token" => "old-refresh-token"))
      .to_return(status: 200, body: { access_token: "fresh-access-token", refresh_token: "new-refresh-token", expires_in: 86400 }.to_json)

    RefreshGhlTokenJob.perform_now

    assert_equal "new-refresh-token", AgencyConnection.find_by!(service: "ghl").credentials["refresh_token"]
  end

  test "does nothing when GHL was never connected" do
    RefreshGhlTokenJob.perform_now

    assert_not_requested :post, "https://services.leadconnectorhq.com/oauth/token"
  end
end
