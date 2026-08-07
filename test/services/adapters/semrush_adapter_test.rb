require "test_helper"

module Adapters
  class SemrushAdapterTest < ActiveSupport::TestCase
    setup do
      @client = Client.create!(name: "Test Practice", onboarding_status: "active", website_url: "example.com")
      @client.client_service_links.create!(service: "semrush", external_id: "project-123",
        override_credentials: { api_key: "semrush-key" }.to_json)
      @report_month = Date.new(2026, 6, 1)
    end

    def stub_tracking(body)
      stub_request(:get, "https://api.semrush.com/reports/v1/projects/project-123/tracking/")
        .with(query: hash_including("key" => "semrush-key", "type" => "tracking_position_organic",
          "action" => "report", "url" => "*.example.com/*", "display_limit" => "500"))
        .to_return(status: 200, body: body)
    end

    def stub_overview(csv_body)
      stub_request(:get, "https://api.semrush.com/")
        .with(query: hash_including("key" => "semrush-key", "type" => "phrase_this", "database" => "us"))
        .to_return(status: 200, body: csv_body)
    end

    test "auto-creates a ClientKeyword for every phrase SEMrush returns, with no pre-existing record needed" do
      assert_equal 0, @client.client_keywords.count

      stub_tracking({
        data: {
          "0" => {
            "Ph" => "Dentist Near Me", # SEMrush returns lowercase in practice; mixed case here proves the match is case-insensitive
            "Fi" => { "*.example.com/*" => 7 },
            "Tr" => { "20260601" => { "*.example.com/*" => 0.5 }, "20260630" => { "*.example.com/*" => 0.81 } }
          },
          "1" => {
            "Ph" => "dental implants",
            "Fi" => { "*.example.com/*" => 3 },
            "Tr" => { "20260630" => { "*.example.com/*" => 0.2 } }
          }
        }
      }.to_json)
      stub_overview("Keyword;Keyword Difficulty Index;Intent;Keywords SERP Features\n" \
        "dentist near me;57;3;3,9,21,36\ndental implants;79;1;5,9,13,20,21,36,43,52")

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_equal 2, result.data[:rankings].size
      assert_equal 2, @client.client_keywords.count

      ranking = result.data[:rankings].find { |r| r[:client_keyword_id] == @client.client_keywords.find_by!(keyword: "dentist near me").id }
      assert_equal 7, ranking[:position]
      assert_equal 0.81, ranking[:potential_traffic] # takes the latest date's Tr, not the earliest
      assert_equal 0.31, ranking[:growth].round(2) # latest Tr minus earliest Tr in the same response
      assert_equal 57, ranking[:keyword_difficulty]
      assert_equal "T", ranking[:intent] # SEMrush's Intent code 3 => Transactional
      assert_equal 4, ranking[:serp_features] # count of Fk codes, not the decoded feature names
    end

    test "reuses an existing ClientKeyword instead of creating a duplicate" do
      existing = @client.client_keywords.create!(keyword: "dentist near me")
      stub_tracking({ data: { "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => 7 }, "Tr" => {} } } }.to_json)
      stub_overview("Keyword;Keyword Difficulty Index;Intent;Keywords SERP Features\ndentist near me;57;3;3,9")

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert_equal 1, @client.client_keywords.count
      assert_equal existing.id, result.data[:rankings].first[:client_keyword_id]
    end

    test "excludes a keyword marked inactive, without dropping it from ClientKeyword" do
      @client.client_keywords.create!(keyword: "dentist near me", active: false)
      stub_tracking({ data: {
        "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => 7 }, "Tr" => {} },
        "1" => { "Ph" => "dental implants", "Fi" => { "*.example.com/*" => 3 }, "Tr" => {} }
      } }.to_json)
      stub_overview("Keyword;Keyword Difficulty Index;Intent;Keywords SERP Features\ndental implants;79;1;5,9")

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert_equal 1, result.data[:rankings].size
      assert_equal "dental implants", @client.client_keywords.find(result.data[:rankings].first[:client_keyword_id]).keyword
      assert @client.client_keywords.exists?(keyword: "dentist near me") # still there, just excluded from the report
    end

    test "growth is nil when only one tracked date is available" do
      stub_tracking({ data: { "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => 7 },
        "Tr" => { "20260630" => { "*.example.com/*" => 0.2 } } } } }.to_json)
      stub_overview("Keyword;Keyword Difficulty Index;Intent;Keywords SERP Features\ndentist near me;57;3;3,9")

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert_nil result.data[:rankings].first[:growth]
    end

    test "treats a \"-\" (not ranked) position as nil" do
      stub_tracking({ data: { "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => "-" }, "Tr" => {} } } }.to_json)
      stub_overview("Keyword;Keyword Difficulty Index;Intent;Keywords SERP Features\ndentist near me;57;3;3,9")

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_nil result.data[:rankings].first[:position]
    end

    test "keyword difficulty, intent, and SF are all nil, not a failure, when the overview call fails" do
      stub_tracking({ data: { "0" => { "Ph" => "dentist near me", "Fi" => { "*.example.com/*" => 7 }, "Tr" => {} } } }.to_json)
      stub_request(:get, "https://api.semrush.com/").with(query: hash_including("type" => "phrase_this")).to_return(status: 500)

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      ranking = result.data[:rankings].first
      assert_nil ranking[:keyword_difficulty]
      assert_nil ranking[:intent]
      assert_nil ranking[:serp_features]
    end

    test "succeeds with an empty rankings list when SEMrush tracks nothing for this project" do
      stub_tracking({ data: {} }.to_json)

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert result.success?
      assert_equal [], result.data[:rankings]
      assert_equal 0, @client.client_keywords.count
    end

    test "fails without raising when no project id is configured" do
      @client.client_service_links.destroy_all

      result = SemrushAdapter.new(@client, report_month: @report_month).call

      assert_not result.success?
    end

    test "check_connection succeeds on a valid, parseable tracking response" do
      stub_tracking({ data: {} }.to_json)

      result = SemrushAdapter.new(@client, report_month: @report_month).call(action: :check_connection)

      assert result.success?
    end

    # SEMrush 404s a bad project ID with a plain-text "campaign not found"
    # body, not JSON — a naive JSON.parse on this would raise, so
    # check_connection must catch the parse failure itself rather than
    # relying on Base#call's Faraday::Error rescue.
    test "check_connection fails on SEMrush's plain-text campaign-not-found body" do
      stub_request(:get, "https://api.semrush.com/reports/v1/projects/project-123/tracking/")
        .with(query: hash_including("key" => "semrush-key"))
        .to_return(status: 200, body: "ERROR 50 :: CAMPAIGN NOT FOUND")

      result = SemrushAdapter.new(@client, report_month: @report_month).call(action: :check_connection)

      assert_not result.success?
      assert_match(/CAMPAIGN NOT FOUND/, result.error)
    end
  end
end
