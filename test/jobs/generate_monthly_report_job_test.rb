require "test_helper"

class GenerateMonthlyReportJobTest < ActiveJob::TestCase
  test "generates a (mostly placeholder) report for a client with no service links configured" do
    client = Client.create!(name: "Bare Practice", onboarding_status: "active")
    month = Date.current.beginning_of_month - 1.month

    GenerateMonthlyReportJob.perform_now(client.id, month.year, month.month)

    report = client.monthly_reports.find_by(report_month: month)
    assert report.present?
    assert report.generated_at.present?
    assert_equal "not_connected", report.report_traffic.ghl_data_status
    assert_equal "success", report.report_generation_logs.last.status
    assert report.report_generation_logs.last.error_log.present? # adapter warnings, still non-fatal
  end

  test "discards rather than retries when the client no longer exists" do
    perform_enqueued_jobs do
      assert_nothing_raised do
        GenerateMonthlyReportJob.perform_later(SecureRandom.uuid, 2026, 6)
      end
    end
  end

  test "enqueues on the default queue" do
    assert_equal "default", GenerateMonthlyReportJob.new.queue_name
  end
end
