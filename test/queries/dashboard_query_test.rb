require "test_helper"

class DashboardQueryTest < ActiveSupport::TestCase
  setup do
    @report_month = Date.new(2026, 6, 1)

    @generated_client = Client.create!(name: "Generated Practice", onboarding_status: "active")
    report = @generated_client.monthly_reports.create!(report_month: @report_month, generated_at: Time.current)
    report.report_generation_logs.create!(status: "success", attempted_at: Time.current, duration_seconds: 42)

    @failed_client = Client.create!(name: "Failed Practice", onboarding_status: "active")
    failed_report = @failed_client.monthly_reports.create!(report_month: @report_month)
    failed_report.report_generation_logs.create!(status: "failed", attempted_at: Time.current, error_summary: "boom")

    @not_yet_client = Client.create!(name: "Not Yet Practice", onboarding_status: "active")

    Client.create!(name: "Pending Practice", onboarding_status: "pending")
  end

  test "buckets each active client by generation status" do
    result = DashboardQuery.new(report_month: @report_month).call

    statuses = result.client_rows.to_h { |row| [ row.client.name, row.status ] }
    assert_equal :generated, statuses["Generated Practice"]
    assert_equal :failed, statuses["Failed Practice"]
    assert_equal :not_yet_generated, statuses["Not Yet Practice"]
    assert_not_includes statuses.keys, "Pending Practice"
  end

  test "counts generated, failed, and pending onboarding" do
    result = DashboardQuery.new(report_month: @report_month).call

    assert_equal 1, result.generated_count
    assert_equal 1, result.failed_count
    assert_equal 1, result.pending_onboarding_count
  end

  test "averages duration across successful logs only" do
    result = DashboardQuery.new(report_month: @report_month).call

    assert_equal 42, result.avg_duration_seconds
  end

  test "lists all five services for data freshness, even unconfigured ones" do
    result = DashboardQuery.new(report_month: @report_month).call

    assert_equal 5, result.connections.size
    assert_equal 5, result.attention_count # none configured yet
  end
end
