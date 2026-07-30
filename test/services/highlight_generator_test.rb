require "test_helper"

class HighlightGeneratorTest < ActiveSupport::TestCase
  setup do
    client = Client.create!(name: "Test Practice", onboarding_status: "active")
    @report = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generated_at: Time.current)
    @report.create_report_traffic!(total_visits: 217, organic_visits: 59, ghl_data_status: "not_connected")
    @report.create_report_citation!(total_impressions: 900, total_engagements: 253)
    @report.create_report_gbp_summary!(total_reviews: 312, average_rating: 4.7, new_positive_reviews: 6)

    @previous_key = ENV["ANTHROPIC_API_KEY"]
  end

  teardown do
    ENV["ANTHROPIC_API_KEY"] = @previous_key
  end

  test "returns blank banners without making a request when no API key is configured" do
    ENV["ANTHROPIC_API_KEY"] = nil

    result = HighlightGenerator.new(@report).call

    assert_nil result[:summary_text]
    assert_nil result[:ai_seo_summary_text]
  end

  test "parses the model's JSON banner response" do
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    model_json = { summary: "Great month overall.", ai_seo_summary: nil }.to_json
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .with(headers: { "x-api-key" => "test-key" })
      .to_return(status: 200, body: { content: [ { type: "text", text: model_json } ] }.to_json)

    result = HighlightGenerator.new(@report).call

    assert_equal "Great month overall.", result[:summary_text]
    assert_nil result[:ai_seo_summary_text]
  end

  test "returns blank banners when the model response isn't valid JSON" do
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: { content: [ { type: "text", text: "not json" } ] }.to_json)

    result = HighlightGenerator.new(@report).call

    assert_nil result[:summary_text]
    assert_nil result[:ai_seo_summary_text]
  end

  test "returns blank banners without raising on an HTTP error" do
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    stub_request(:post, "https://api.anthropic.com/v1/messages").to_return(status: 500, body: "error")

    result = HighlightGenerator.new(@report).call

    assert_nil result[:summary_text]
  end
end
