require "test_helper"

class ServiceSyncLogTest < ActiveSupport::TestCase
  setup do
    @client = Client.create!(name: "Adams Dental Associates #{SecureRandom.hex(4)}", onboarding_status: "active")
  end

  test "average_duration_for averages the most recent successful checks" do
    log_durations("ghl", [ 1000, 2000, 3000 ])

    assert_equal 2000, ServiceSyncLog.average_duration_for("ghl")
  end

  # The 4-row window is what keeps the countdown responsive to a service that
  # has recently got slower or faster, instead of averaging its whole history.
  test "average_duration_for looks at no more than the last four checks" do
    log_durations("ghl", [ 9999, 1000, 1000, 1000, 1000 ])

    assert_equal 1000, ServiceSyncLog.average_duration_for("ghl")
  end

  # A not_found check is as slow as a successful one, but an errored check
  # usually fails fast — averaging those in would under-estimate the countdown.
  test "average_duration_for ignores rows that were not successful" do
    log_durations("ghl", [ 2000 ])
    log_durations("ghl", [ 10 ], status: :error)
    log_durations("ghl", [ 20 ], status: :not_found)

    assert_equal 2000, ServiceSyncLog.average_duration_for("ghl")
  end

  test "average_duration_for ignores other services' checks" do
    log_durations("yext", [ 5000 ])

    assert_equal 0, ServiceSyncLog.average_duration_for("ghl")
  end

  # Zero is the "no history" signal the caller branches on to fall back to its
  # own default estimate (see Clients::SyncServicesController#create).
  test "average_duration_for returns zero when a service has never been checked" do
    assert_equal 0, ServiceSyncLog.average_duration_for("ghl")
  end

  private

  # Explicit, increasing created_at values — rows written in the same instant
  # leave "the last four" ambiguous, so the window test couldn't be trusted.
  # Listed oldest-first, matching how the assertions read.
  def log_durations(service, durations, status: :success)
    durations.each_with_index do |duration_ms, index|
      ServiceSyncLog.create!(client: @client, service: service, duration_ms: duration_ms,
        status: status, created_at: index.minutes.from_now)
    end
  end
end
