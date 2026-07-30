require "test_helper"

module Adapters
  class HubspotAdapterTest < ActiveSupport::TestCase
    setup do
      @client = Client.create!(name: "Test Practice", onboarding_status: "active")
      @client.client_service_links.create!(service: "hubspot", external_id: "company-123")
      AgencyConnection.create!(service: "hubspot", encrypted_credentials: { access_token: "agency-token" }.to_json)
    end

    test "maps HubSpot company properties into a success result" do
      stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-123")
        .with(query: hash_including("properties"), headers: { "Authorization" => "Bearer agency-token" })
        .to_return(
          status: 200,
          body: {
            properties: {
              name: "Test Practice", address: "1 Main St", website: "example.com",
              onboarding_status: "active", onboarded_at: "2026-01-15", ai_seo_enrolled: "true"
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = HubspotAdapter.new(@client).call

      assert result.success?
      assert_equal "Test Practice", result.data[:name]
      assert_equal Date.new(2026, 1, 15), result.data[:onboarded_at]
      assert_equal true, result.data[:ai_seo_enrolled]
    end

    test "fails without raising when no credentials are configured" do
      AgencyConnection.destroy_all
      @client.client_service_links.destroy_all

      result = HubspotAdapter.new(@client).call

      assert_not result.success?
      assert_match(/no credentials/, result.error)
    end

    test "fails without raising on an HTTP error" do
      stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-123")
        .with(query: hash_including("properties"))
        .to_return(status: 401, body: "unauthorized")

      result = HubspotAdapter.new(@client).call

      assert_not result.success?
      assert_match(/hubspot/, result.error)
    end
  end
end
