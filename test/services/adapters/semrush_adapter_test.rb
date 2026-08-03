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

    def stub_tracking(body)
      stub_request(:get, "https://api.semrush.com/reports/v1/projects/project-123/tracking/")
        .with(query: hash_including("key" => "semrush-key", "type" => "tracking_position_organic",
          "action" => "report", "url" => "*.example.com/*", "display_limit" => "500"))
        .to_return(status: 200, body: body)
    end

    def stub_kd(csv_body)
      stub_request(:get, "https://api.semrush.com/")
        .with(query: hash_including("key" => "semrush-key", "type" => "phrase_kdi", "database" => "us"))
        .to_return(status: 200, body: csv_body)
    end

    test "maps live-shaped JSON rankings onto tracked client keywords" do
      stub_tracking({
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
      }.to_json)
      stub_kd("Keyword;Keyword Difficulty Index\ndentist near me;57")

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      ranking = result.data[:rankings].first
      assert_equal @keyword.id, ranking[:client_keyword_id]
      assert_equal 7, ranking[:position]
      assert_equal 0.81, ranking[:potential_traffic] # takes the latest date's Tr, not the earliest
      assert_equal 0.31, ranking[:growth].round(2) # latest Tr minus earliest Tr in the same response
      assert_equal 57, ranking[:keyword_difficulty]
    end

    test "growth is nil when only one tracked date is available" do
      stub_tracking({ data: { "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => 7 },
        "Tr" => { "20260630" => { "*.example.com/*" => 0.2 } } } } }.to_json)
      stub_kd("Keyword;Keyword Difficulty Index\ndentist near me;57")

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert_nil result.data[:rankings].first[:growth]
    end

    test "treats a \"-\" (not ranked) position as nil" do
      stub_tracking({ data: { "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => "-" }, "Tr" => {} } } }.to_json)
      stub_kd("Keyword;Keyword Difficulty Index\ndentist near me;57")

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_nil result.data[:rankings].first[:position]
    end

    test "keyword difficulty is nil, not a failure, when the KD call fails" do
      stub_tracking({ data: { "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => 7 }, "Tr" => {} } } }.to_json)
      stub_request(:get, "https://api.semrush.com/").with(query: hash_including("type" => "phrase_kdi")).to_return(status: 500)

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_nil result.data[:rankings].first[:keyword_difficulty]
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
