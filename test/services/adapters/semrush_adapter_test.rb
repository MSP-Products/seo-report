require "test_helper"

module Adapters
  class SemrushAdapterTest < ActiveSupport::TestCase
    setup do
      @client = Client.create!(name: "Test Practice", onboarding_status: "active", website_url: "example.com")
      @client.client_service_links.create!(service: "semrush", external_id: "project-123",
        override_credentials: { api_key: "semrush-key" }.to_json)
      @keyword = @client.client_keywords.create!(keyword: "dentist near me", intent: "T")
      @report_month = Date.new(2026, 6, 1)
    end

    test "maps CSV-style rankings onto tracked client keywords" do
      body = "Ph;Po;Pp\ndentist near me;7;0.81\n"
      stub_request(:get, "https://api.semrush.com/reports/v1/projects/project-123/tracking/rankings")
        .with(query: hash_including("key" => "semrush-key", "domain" => "example.com"))
        .to_return(status: 200, body: body)

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      ranking = result.data[:rankings].first
      assert_equal @keyword.id, ranking[:client_keyword_id]
      assert_equal 7, ranking[:position]
      assert_equal 0.81, ranking[:potential_traffic]
    end

    test "succeeds with an empty rankings list when the client has no tracked keywords" do
      @keyword.destroy!

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_equal [], result.data[:rankings]
    end

    test "fails without raising when no project id is configured" do
      @client.client_service_links.destroy_all

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert_not result.success?
    end
  end
end
