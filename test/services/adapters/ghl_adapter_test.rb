require "test_helper"

module Adapters
  class GhlAdapterTest < ActiveSupport::TestCase
    setup do
      @client = Client.create!(name: "Test Practice", onboarding_status: "active")
      @client.client_service_links.create!(service: "ghl", external_id: "location-123",
        override_credentials: { access_token: "loc-token" }.to_json)
      @report_month = Date.new(2026, 6, 1)
    end

    test "counts appointments across every calendar and sums won-opportunity revenue" do
      stub_request(:get, "https://services.leadconnectorhq.com/calendars/")
        .with(query: hash_including("locationId" => "location-123"))
        .to_return(status: 200, body: { calendars: [ { id: "cal-1" }, { id: "cal-2" } ] }.to_json)

      stub_request(:get, "https://services.leadconnectorhq.com/calendars/events")
        .with(query: hash_including("locationId" => "location-123", "calendarId" => "cal-1"))
        .to_return(status: 200, body: { events: [ { id: "1" }, { id: "2" } ] }.to_json)
      stub_request(:get, "https://services.leadconnectorhq.com/calendars/events")
        .with(query: hash_including("locationId" => "location-123", "calendarId" => "cal-2"))
        .to_return(status: 200, body: { events: [ { id: "3" } ] }.to_json)

      stub_request(:get, "https://services.leadconnectorhq.com/opportunities/search")
        .with(query: hash_including("location_id" => "location-123", "status" => "won",
          "date" => "06-01-2026", "endDate" => "06-30-2026"))
        .to_return(status: 200, body: { opportunities: [ { monetaryValue: 100.5 }, { monetaryValue: 200 } ] }.to_json)

      result = GhlAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_equal 3, result.data[:appointments_booked]
      assert_equal 300.5, result.data[:estimated_revenue]
      assert_equal "connected", result.data[:ghl_data_status]
    end

    test "fails without raising when no location id is configured" do
      @client.client_service_links.destroy_all

      result = GhlAdapter.new(@client, report_month: @report_month).call

      assert_not result.success?
      assert_match(/no credentials|location id/, result.error)
    end

    test "check_connection lists calendars without fetching events or revenue" do
      stub_request(:get, "https://services.leadconnectorhq.com/calendars/")
        .with(query: hash_including("locationId" => "location-123"))
        .to_return(status: 200, body: { calendars: [ { id: "cal-1" } ] }.to_json)

      result = GhlAdapter.new(@client, report_month: @report_month).call(action: :check_connection)

      assert result.success?
      assert_not_requested :get, "https://services.leadconnectorhq.com/calendars/events"
      assert_not_requested :get, "https://services.leadconnectorhq.com/opportunities/search"
    end

    test "check_connection flags a deleted location as not_found" do
      stub_request(:get, "https://services.leadconnectorhq.com/calendars/")
        .with(query: hash_including("locationId" => "location-123")).to_return(status: 404, body: "not found")

      result = GhlAdapter.new(@client, report_month: @report_month).call(action: :check_connection)

      assert_not result.success?
      assert result.not_found
    end

    test "a per-client override token is used as-is, without calling GHL's OAuth endpoints" do
      stub_request(:get, "https://services.leadconnectorhq.com/calendars/")
        .with(query: hash_including("locationId" => "location-123"), headers: { "Authorization" => "Bearer loc-token" })
        .to_return(status: 200, body: { calendars: [] }.to_json)
      stub_request(:get, "https://services.leadconnectorhq.com/opportunities/search")
        .with(query: hash_including("location_id" => "location-123"), headers: { "Authorization" => "Bearer loc-token" })
        .to_return(status: 200, body: { opportunities: [] }.to_json)

      result = GhlAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_not_requested :post, "https://services.leadconnectorhq.com/oauth/token"
      assert_not_requested :post, "https://services.leadconnectorhq.com/oauth/locationToken"
    end

    test "with no client override, mints a location token from the agency-wide OAuth grant" do
      @client.client_service_links.destroy_all
      @client.client_service_links.create!(service: "ghl", external_id: "location-123")
      AgencyConnection.create!(service: "ghl", encrypted_credentials: {
        access_token: "agency-access-token", refresh_token: "agency-refresh-token", company_id: "company-abc"
      }.to_json, expires_at: 23.hours.from_now)

      stub_request(:post, "https://services.leadconnectorhq.com/oauth/locationToken")
        .with(body: hash_including("companyId" => "company-abc", "locationId" => "location-123"))
        .to_return(status: 200, body: { access_token: "minted-location-token" }.to_json)

      stub_request(:get, "https://services.leadconnectorhq.com/calendars/")
        .with(query: hash_including("locationId" => "location-123"), headers: { "Authorization" => "Bearer minted-location-token" })
        .to_return(status: 200, body: { calendars: [] }.to_json)
      stub_request(:get, "https://services.leadconnectorhq.com/opportunities/search")
        .with(query: hash_including("location_id" => "location-123"), headers: { "Authorization" => "Bearer minted-location-token" })
        .to_return(status: 200, body: { opportunities: [] }.to_json)

      result = GhlAdapter.new(@client, report_month: @report_month).call

      assert result.success?
    end
  end
end
