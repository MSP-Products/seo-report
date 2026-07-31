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

    test "maps live-shaped JSON rankings onto tracked client keywords" do
      body = {
        data: {
          "0" => {
            "Ph" => "Dentist Near Me", # SEMrush returns lowercase in practice; mixed case here proves the match is case-insensitive
            "Fi" => { "*.example.com/*" => 7 },
            "Tr" => { "20260601" => { "*.example.com/*" => 0.5 }, "20260630" => { "*.example.com/*" => 0.81 } }
          },
          "1" => {
            "Ph" => "some other practice's keyword",
            "Fi" => { "*.example.com/*" => 3 },
            "Tr" => { "20260630" => { "*.example.com/*" => 0.2 } }
          }
        }
      }.to_json
      stub_request(:get, "https://api.semrush.com/reports/v1/projects/project-123/tracking/")
        .with(query: hash_including("key" => "semrush-key", "type" => "tracking_position_organic",
          "action" => "report", "url" => "*.example.com/*", "display_limit" => "500"))
        .to_return(status: 200, body: body)

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      ranking = result.data[:rankings].first
      assert_equal @keyword.id, ranking[:client_keyword_id]
      assert_equal 7, ranking[:position]
      assert_equal 0.81, ranking[:potential_traffic] # takes the latest date's Tr, not the earliest
    end

    test "treats a \"-\" (not ranked) position as nil" do
      body = { data: { "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => "-" }, "Tr" => {} } } }.to_json
      stub_request(:get, "https://api.semrush.com/reports/v1/projects/project-123/tracking/")
        .with(query: hash_including("key" => "semrush-key"))
        .to_return(status: 200, body: body)

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_nil result.data[:rankings].first[:position]
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
