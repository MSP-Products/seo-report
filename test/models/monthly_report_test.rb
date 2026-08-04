require "test_helper"

class MonthlyReportTest < ActiveSupport::TestCase
  test "reporting_month is always last month, never the current one" do
    travel_to Date.new(2026, 8, 15) do
      assert_equal Date.new(2026, 7, 1), MonthlyReport.reporting_month
    end
  end

  test "reporting_month follows the calendar across a year boundary" do
    travel_to Date.new(2026, 1, 10) do
      assert_equal Date.new(2025, 12, 1), MonthlyReport.reporting_month
    end
  end

  test "generation_status is :generated once generated_at is set" do
    client = Client.create!(name: "Generated Practice", onboarding_status: "active")
    report = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generated_at: Time.current)

    assert_equal :generated, report.generation_status
  end

  test "generation_status is :failed when the latest attempt failed and nothing has generated" do
    client = Client.create!(name: "Failed Practice", onboarding_status: "active")
    report = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1))
    report.report_generation_logs.create!(status: "failed", attempted_at: 1.hour.ago, error_summary: "boom")
    report.report_generation_logs.create!(status: "failed", attempted_at: Time.current, error_summary: "boom again")

    assert_equal :failed, report.generation_status
  end

  test "generation_status is :not_yet_generated when no attempt has been logged" do
    client = Client.create!(name: "Untouched Practice", onboarding_status: "active")
    report = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1))

    assert_equal :not_yet_generated, report.generation_status
  end
end
