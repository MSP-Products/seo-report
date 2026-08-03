require "test_helper"

class MonthlyReportTest < ActiveSupport::TestCase
  test "for_report_log orders newest cycle first, then newest attempt" do
    client = Client.create!(name: "List Order Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    older_month = client.monthly_reports.create!(report_month: Date.new(2026, 5, 1), generation_status: "ready")
    newer_month = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generation_status: "ready")

    ids = MonthlyReport.for_report_log.where(client_id: client.id).pluck(:id)
    assert_equal [ newer_month.id, older_month.id ], ids
  end

  test "for_report_log scopes to one month when given" do
    client = Client.create!(name: "List Scope Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    may = client.monthly_reports.create!(report_month: Date.new(2026, 5, 1), generation_status: "ready")
    client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generation_status: "ready")

    reports = MonthlyReport.for_report_log(month: Date.new(2026, 5, 1)).where(client_id: client.id)
    assert_equal [ may ], reports.to_a
  end

  test "parse_month_param parses a YYYY-MM string and returns nil for anything else" do
    assert_equal Date.new(2026, 7, 1), MonthlyReport.parse_month_param("2026-07")
    assert_nil MonthlyReport.parse_month_param(nil)
    assert_nil MonthlyReport.parse_month_param("")
    assert_nil MonthlyReport.parse_month_param("not-a-month")
  end

  test "effective_status is the generation_status while not ready" do
    client = Client.create!(name: "Not Ready Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    queued = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generation_status: "queued")
    assert_equal "queued", queued.effective_status

    generating = client.monthly_reports.create!(report_month: Date.new(2026, 5, 1), generation_status: "generating")
    assert_equal "generating", generating.effective_status

    failed = client.monthly_reports.create!(report_month: Date.new(2026, 4, 1), generation_status: "failed")
    assert_equal "failed", failed.effective_status
  end

  test "effective_status distinguishes ready, sent, and held" do
    client = Client.create!(name: "Ready Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    ready = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generation_status: "ready", generated_at: Time.current)
    assert_equal "ready", ready.effective_status

    sent = client.monthly_reports.create!(report_month: Date.new(2026, 5, 1), generation_status: "ready",
      generated_at: Time.current, emailed_at: Time.current)
    assert_equal "sent", sent.effective_status

    held = client.monthly_reports.create!(report_month: Date.new(2026, 4, 1), generation_status: "ready", generated_at: Time.current)
    held.send_logs.create!(status: "held", attempted_at: Time.current, error_message: "HubSpot token rejected")
    assert_equal "held", held.reload.effective_status
  end
end
