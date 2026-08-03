require "test_helper"

class EnqueueMonthlyReportsJobTest < ActiveJob::TestCase
  test "enqueues a generate job for every active client for the last completed month" do
    active = Client.create!(name: "Active Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    Client.create!(name: "Pending Practice #{SecureRandom.hex(4)}", onboarding_status: "pending")
    month = Date.current.beginning_of_month - 1.month

    assert_enqueued_with(job: GenerateMonthlyReportJob, args: [ active.id, month.year, month.month ]) do
      EnqueueMonthlyReportsJob.perform_now
    end
  end

  test "creates a queued report for each active client up front, before the job runs" do
    client = Client.create!(name: "Fresh Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    month = Date.current.beginning_of_month - 1.month

    EnqueueMonthlyReportsJob.perform_now

    report = client.monthly_reports.find_by(report_month: month)
    assert report.present?
    assert report.queued?
  end

  test "does not enqueue for a client whose report is already ready" do
    client = Client.create!(name: "Done Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    month = Date.current.beginning_of_month - 1.month
    client.monthly_reports.create!(report_month: month, generated_at: Time.current, generation_status: "ready")

    EnqueueMonthlyReportsJob.perform_now

    assert_not_includes enqueued_client_ids, client.id
  end

  test "re-enqueues a client whose report previously failed" do
    client = Client.create!(name: "Retry Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    month = Date.current.beginning_of_month - 1.month
    client.monthly_reports.create!(report_month: month, generation_status: "failed", attempt_count: 1)

    assert_includes enqueued_client_ids_from { EnqueueMonthlyReportsJob.perform_now }, client.id
  end

  test "does not enqueue for a discarded client" do
    client = Client.create!(name: "Gone Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    client.discard

    EnqueueMonthlyReportsJob.perform_now

    assert_not_includes enqueued_client_ids, client.id
  end

  test "does not enqueue for a pending client" do
    client = Client.create!(name: "Pending Only Practice #{SecureRandom.hex(4)}", onboarding_status: "pending")

    EnqueueMonthlyReportsJob.perform_now

    assert_not_includes enqueued_client_ids, client.id
  end

  private

  # Real onboarded clients from db/seeds.rb are present in the test DB alongside
  # whatever this test creates, so "does not enqueue" must check for this specific
  # client's id rather than assert the queue is empty.
  def enqueued_client_ids
    enqueued_jobs.select { |job| job["job_class"] == "GenerateMonthlyReportJob" }
      .map { |job| job["arguments"].first }
  end

  def enqueued_client_ids_from
    yield
    enqueued_client_ids
  end
end
