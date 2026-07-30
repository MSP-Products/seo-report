require "test_helper"

module Adapters
  class GhlAdapterTest < ActiveSupport::TestCase
    setup do
      @client = Client.create!(name: "Test Practice", onboarding_status: "active")
      @client.client_service_links.create!(service: "ghl", external_id: "location-123",
        override_credentials: { access_token: "loc-token" }.to_json)
      @report_month = Date.new(2026, 6, 1)
    end

    test "counts appointments and sums won-opportunity revenue" do
      stub_request(:get, "https://services.leadconnectorhq.com/calendars/events")
        .with(query: hash_including("locationId" => "location-123"))
        .to_return(status: 200, body: { events: [ { id: "1" }, { id: "2" } ] }.to_json)

      stub_request(:get, "https://services.leadconnectorhq.com/opportunities/search")
        .with(query: hash_including("location_id" => "location-123", "status" => "won"))
        .to_return(status: 200, body: { opportunities: [ { monetaryValue: 100.5 }, { monetaryValue: 200 } ] }.to_json)

      result = GhlAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_equal 2, result.data[:appointments_booked]
      assert_equal 300.5, result.data[:estimated_revenue]
      assert_equal "connected", result.data[:ghl_data_status]
    end

    test "fails without raising when no location id is configured" do
      @client.client_service_links.destroy_all

      result = GhlAdapter.new(@client, report_month: @report_month).call

      assert_not result.success?
      assert_match(/no credentials|location id/, result.error)
    end
  end
end
