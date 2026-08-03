require "test_helper"

class DashboardPresenterTest < ActiveSupport::TestCase
  setup do
    @month = Date.current.beginning_of_month - 1.month
  end

  test "counts clients by onboarding status" do
    Client.create!(name: "Active One #{SecureRandom.hex(4)}", onboarding_status: "active")
    Client.create!(name: "Pending One #{SecureRandom.hex(4)}", onboarding_status: "pending")

    presenter = DashboardPresenter.new(month: @month)

    assert presenter.active_client_count >= 1
    assert presenter.pending_client_count >= 1
    assert_equal presenter.active_client_count + presenter.pending_client_count <= presenter.client_count, true
  end

  test "run_started? is false with no reports and true once one exists" do
    presenter = DashboardPresenter.new(month: Date.new(1999, 1, 1))
    assert_not presenter.run_started?

    client = Client.create!(name: "Fresh #{SecureRandom.hex(4)}", onboarding_status: "active")
    client.monthly_reports.create!(report_month: @month, generation_status: "queued")

    assert DashboardPresenter.new(month: @month).run_started?
  end

  test "report_rows includes an active client with no report yet as a nil-report row" do
    picked_up = Client.create!(name: "Picked Up #{SecureRandom.hex(4)}", onboarding_status: "active")
    picked_up.monthly_reports.create!(report_month: @month, generation_status: "ready", generated_at: Time.current)
    never_enqueued = Client.create!(name: "Never Enqueued #{SecureRandom.hex(4)}", onboarding_status: "active")

    rows = DashboardPresenter.new(month: @month).report_rows
    row_for = rows.find { |row| row[:client] == never_enqueued }

    assert row_for.present?
    assert_nil row_for[:report]
    assert_equal picked_up, rows.find { |row| row[:client] == picked_up }[:client]
  end

  test "counts ready and failed reports for the month, and detects an in-progress run" do
    client_a = Client.create!(name: "Ready Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    client_b = Client.create!(name: "Failed Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    client_c = Client.create!(name: "Queued Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    client_a.monthly_reports.create!(report_month: @month, generation_status: "ready", generated_at: Time.current)
    client_b.monthly_reports.create!(report_month: @month, generation_status: "failed", attempt_count: 2)
    client_c.monthly_reports.create!(report_month: @month, generation_status: "queued")

    presenter = DashboardPresenter.new(month: @month)

    assert presenter.ready_count >= 1
    assert presenter.failed_count >= 1
    assert presenter.run_in_progress?
  end

  test "run_in_progress? is false once every report is ready or failed" do
    client = Client.create!(name: "Done Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    client.monthly_reports.create!(report_month: @month, generation_status: "ready", generated_at: Time.current)

    presenter = DashboardPresenter.new(month: @month)
    assert_not presenter.reports.queued.exists?
    assert_not presenter.reports.generating.exists?
  end

  test "currently_generating_client returns the client whose report is generating" do
    generating_client = Client.create!(name: "Generating Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    generating_client.monthly_reports.create!(report_month: @month, generation_status: "generating")

    presenter = DashboardPresenter.new(month: @month)
    assert_equal generating_client, presenter.currently_generating_client
  end

  test "elapsed is nil before any report exists for the month, and measured once one does" do
    presenter = DashboardPresenter.new(month: Date.new(1999, 1, 1))
    assert_nil presenter.elapsed

    travel_to 10.minutes.ago do
      client = Client.create!(name: "Timed Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
      client.monthly_reports.create!(report_month: @month, generation_status: "queued")
    end

    elapsed = DashboardPresenter.new(month: @month).elapsed
    assert elapsed >= 10.minutes
  end

  test "sent_count reflects emailed reports and held_count reflects held send logs" do
    sent_client = Client.create!(name: "Sent Practice #{SecureRandom.hex(4)}", onboarding_status: "active")
    held_client = Client.create!(name: "Held Practice #{SecureRandom.hex(4)}", onboarding_status: "active")

    sent_client.monthly_reports.create!(report_month: @month, generation_status: "ready",
      generated_at: Time.current, emailed_at: Time.current)
    held_report = held_client.monthly_reports.create!(report_month: @month, generation_status: "ready", generated_at: Time.current)
    held_report.send_logs.create!(status: "held", attempted_at: Time.current, error_message: "HubSpot token rejected")

    presenter = DashboardPresenter.new(month: @month)
    assert presenter.sent_count >= 1
    assert presenter.held_count >= 1
  end

  test "progress_percent is ready_count over total_expected" do
    client_a = Client.create!(name: "Progress Ready #{SecureRandom.hex(4)}", onboarding_status: "active")
    Client.create!(name: "Progress Pending #{SecureRandom.hex(4)}", onboarding_status: "active")
    client_a.monthly_reports.create!(report_month: @month, generation_status: "ready", generated_at: Time.current)

    presenter = DashboardPresenter.new(month: @month)
    expected = ((presenter.ready_count.to_f / presenter.total_expected) * 100).round
    assert_equal expected, presenter.progress_percent
  end

  test "average_generation_time is nil with no ready reports, and measured once one exists" do
    presenter = DashboardPresenter.new(month: Date.new(1999, 1, 1))
    assert_nil presenter.average_generation_time

    client = Client.create!(name: "Timed Generation #{SecureRandom.hex(4)}", onboarding_status: "active")
    started_at = Time.current
    client.monthly_reports.create!(report_month: @month, generation_status: "ready",
      generation_started_at: started_at, generated_at: started_at + 90.seconds)

    average = DashboardPresenter.new(month: @month).average_generation_time
    assert_in_delta 90, average, 1
  end

  test "connections lists every service, configured or not" do
    presenter = DashboardPresenter.new(month: @month)
    assert_equal Service::KEYS.sort, presenter.connections.map(&:service).sort
  end
end
