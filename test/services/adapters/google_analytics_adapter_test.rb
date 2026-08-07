require "test_helper"

module Adapters
  class GoogleAnalyticsAdapterTest < ActiveSupport::TestCase
    setup do
      @private_key = OpenSSL::PKey::RSA.generate(2048)
      AgencyConnection.create!(service: "google_analytics", encrypted_credentials: {
        client_email: "reports@msp.iam.gserviceaccount.com",
        private_key: @private_key.to_pem
      }.to_json)
      @client = Client.create!(name: "Test Practice", onboarding_status: "active")
      @client.client_service_links.create!(service: "google_analytics", external_id: "384938446")
      @report_month = Date.new(2026, 6, 1)
      @runreport_url = "https://analyticsdata.googleapis.com/v1beta/properties/384938446:runReport"

      stub_request(:post, "https://oauth2.googleapis.com/token")
        .to_return(status: 200, body: { access_token: "ga4-token", expires_in: 3600, token_type: "Bearer" }.to_json)
    end

    test "maps overview totals and channel breakdown into report_traffic fields" do
      stub_request(:post, @runreport_url)
        .with(body: hash_including("dimensions" => []))
        .to_return(status: 200, body: {
          rows: [ { dimensionValues: [], metricValues: [ { value: "500" }, { value: "420" }, { value: "2.3" } ] } ]
        }.to_json)
      stub_request(:post, @runreport_url)
        .with(body: hash_including("dimensions" => [ { "name" => "sessionDefaultChannelGroup" } ]))
        .to_return(status: 200, body: {
          rows: [
            { dimensionValues: [ { value: "Organic Search" } ], metricValues: [ { value: "200" } ] },
            { dimensionValues: [ { value: "Direct" } ], metricValues: [ { value: "150" } ] },
            { dimensionValues: [ { value: "Referral" } ], metricValues: [ { value: "50" } ] },
            { dimensionValues: [ { value: "Paid Search" } ], metricValues: [ { value: "70" } ] },
            { dimensionValues: [ { value: "Paid Social" } ], metricValues: [ { value: "30" } ] }
          ]
        }.to_json)

      result = GoogleAnalyticsAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_equal 500, result.data[:total_visits]
      assert_equal 420, result.data[:unique_visitors]
      assert_equal 2.3, result.data[:pages_per_visit]
      assert_equal 200, result.data[:organic_visits]
      assert_equal 150, result.data[:direct_visits]
      assert_equal 50, result.data[:referral_visits]
      assert_equal 100, result.data[:paid_visits] # Paid Search + Paid Social
    end

    test "treats an empty overview report as all-nil rather than raising" do
      stub_request(:post, @runreport_url).to_return(status: 200, body: { rows: [] }.to_json)

      result = GoogleAnalyticsAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_nil result.data[:total_visits]
      assert_equal 0, result.data[:paid_visits] # sum over no matching channels is 0, not nil
    end

    test "fails without raising when no property id is configured" do
      @client.client_service_links.destroy_all

      result = GoogleAnalyticsAdapter.new(@client, report_month: @report_month).call

      assert_not result.success?
      assert_match(/no GA4 property/, result.error)
    end

    test "signs the token request assertion with RS256 using the service account's private key" do
      stub_request(:post, @runreport_url).to_return(status: 200, body: { rows: [] }.to_json)

      GoogleAnalyticsAdapter.new(@client, report_month: @report_month).call

      assert_requested(:post, "https://oauth2.googleapis.com/token") do |req|
        assertion = URI.decode_www_form(req.body).to_h["assertion"]
        header_b64, payload_b64, signature_b64 = assertion.split(".")
        payload = JSON.parse(Base64.urlsafe_decode64(payload_b64))
        signature = Base64.urlsafe_decode64(signature_b64)

        payload["iss"] == "reports@msp.iam.gserviceaccount.com" &&
          @private_key.public_key.verify(OpenSSL::Digest.new("SHA256"), signature, "#{header_b64}.#{payload_b64}")
      end
    end

    test "check_connection requests only the sessions metric, with no channel breakdown" do
      stub_request(:post, @runreport_url)
        .with(body: hash_including("metrics" => [ { "name" => "sessions" } ], "dimensions" => []))
        .to_return(status: 200, body: { rows: [] }.to_json)

      result = GoogleAnalyticsAdapter.new(@client, report_month: @report_month).call(action: :check_connection)

      assert result.success?
      assert_requested(:post, @runreport_url, times: 1)
    end

    test "check_connection flags a deleted GA4 property as not_found" do
      stub_request(:post, @runreport_url).to_return(status: 404, body: "not found")

      result = GoogleAnalyticsAdapter.new(@client, report_month: @report_month).call(action: :check_connection)

      assert_not result.success?
      assert result.not_found
    end
  end
end
