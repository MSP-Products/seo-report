require "test_helper"

module Adapters
  class HubspotAdapterTest < ActiveSupport::TestCase
    setup do
      @client = Client.create!(name: "Test Practice", onboarding_status: "active")
      @client.client_service_links.create!(service: "hubspot", external_id: "company-123")
      AgencyConnection.create!(service: "hubspot", encrypted_credentials: { access_token: "agency-token" }.to_json)
    end

    test "maps an active client enrolled in AI SEO, with an onboarding date" do
      stub_company_properties(active: "true", service_purchased: "Premium Hosting;AI SEO;Scheduler",
        gmb_seo_start_date: "2024-02-19")

      result = HubspotAdapter.new(@client).call

      assert result.success?
      assert_equal "Test Practice", result.data[:name]
      assert_equal "1 Main St", result.data[:address]
      assert_equal "example.com", result.data[:website_url]
      assert_equal "active", result.data[:onboarding_status]
      assert_equal Date.new(2024, 2, 19), result.data[:onboarded_at]
      assert_equal true, result.data[:ai_seo_enrolled]
    end

    test "maps an inactive client as offboarded and not AI SEO enrolled" do
      stub_company_properties(active: "false", service_purchased: "Premium Hosting;Scheduler", gmb_seo_start_date: nil)

      result = HubspotAdapter.new(@client).call

      assert result.success?
      assert_equal "offboarded", result.data[:onboarding_status]
      assert_equal false, result.data[:ai_seo_enrolled]
    end

    test "is not AI SEO enrolled when service_purchased is blank" do
      stub_company_properties(active: "true", service_purchased: nil, gmb_seo_start_date: nil)

      result = HubspotAdapter.new(@client).call

      assert result.success?
      assert_equal false, result.data[:ai_seo_enrolled]
    end

    test "onboarded_at is nil when gmb_seo_start_date is blank" do
      stub_company_properties(active: "true", service_purchased: "AI SEO", gmb_seo_start_date: nil)

      result = HubspotAdapter.new(@client).call

      assert result.success?
      assert_nil result.data[:onboarded_at]
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

    private

    def stub_company_properties(active:, service_purchased:, gmb_seo_start_date:)
      stub_request(:get, "https://api.hubapi.com/crm/v3/objects/companies/company-123")
        .with(query: hash_including("properties"), headers: { "Authorization" => "Bearer agency-token" })
        .to_return(
          status: 200,
          body: {
            properties: {
              name: "Test Practice", address: "1 Main St", website: "example.com",
              active: active, service_purchased: service_purchased, gmb_seo_start_date: gmb_seo_start_date
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end
  end
end
