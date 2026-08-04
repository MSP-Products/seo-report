require "test_helper"

class ReportGenerationSchedulerTest < ActiveJob::TestCase
  setup do
    @month = MonthlyReport.reporting_month
  end

  test "with a client_id, always enqueues that client regardless of existing status" do
    client = Client.create!(name: "Already Done", onboarding_status: "active")
    client.monthly_reports.create!(report_month: @month, generated_at: Time.current)

    assert_enqueued_with(job: GenerateMonthlyReportJob, args: [ client.id, @month.year, @month.month ]) do
      ReportGenerationScheduler.new(client_id: client.id).call
    end
  end

  test "bulk run enqueues clients without a completed report and skips ones already done" do
    pending_client = Client.create!(name: "Needs A Report", onboarding_status: "active")
    done_client = Client.create!(name: "Already Done", onboarding_status: "active")
    done_client.monthly_reports.create!(report_month: @month, generated_at: Time.current)
    inactive_client = Client.create!(name: "Not Active", onboarding_status: "pending")

    ReportGenerationScheduler.new.call

    assert enqueued_for?(pending_client)
    assert_not enqueued_for?(done_client)
    assert_not enqueued_for?(inactive_client)
  end

  private

  def enqueued_for?(client)
    enqueued_jobs.any? { |job| job[:job] == GenerateMonthlyReportJob && job[:args].first == client.id }
  end
end
