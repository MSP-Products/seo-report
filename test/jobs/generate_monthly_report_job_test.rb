require "test_helper"

class GenerateMonthlyReportJobTest < ActiveJob::TestCase
  test "fails to generate a report for a client with no service links configured" do
    # HubSpot, GA4, Yext, and SEMrush are all mandatory (see ReportGenerator)
    # — a client with none of them configured can't generate at all.
    client = Client.create!(name: "Bare Practice", onboarding_status: "active")
    month = Date.current.beginning_of_month - 1.month

    assert_raises(ReportGenerator::AdapterFailureError) do
      GenerateMonthlyReportJob.perform_now(client.id, month.year, month.month)
    end

    report = client.monthly_reports.find_by(report_month: month)
    assert report.present?
    assert report.failed?
    assert_equal "failed", report.report_generation_logs.last.status
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
