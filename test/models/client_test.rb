require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "find_or_create_monthly_report marks the onboarding month as the first report, per HubSpot's onboarded_at" do
    client = Client.create!(name: "Onboarded Practice #{SecureRandom.hex(4)}", onboarding_status: "active",
      onboarded_at: Date.new(2026, 2, 19))

    report = client.find_or_create_monthly_report(Date.new(2026, 2, 1))

    assert report.is_first_report?
  end

  test "find_or_create_monthly_report does not mark a later month as first, even with no prior report" do
    # This is the exact case the HubSpot-sourced onboarding date fixes: a
    # client onboarded in February, backfilled starting in June — June is
    # not their first month even though no report exists before it yet.
    client = Client.create!(name: "Backfilled Practice #{SecureRandom.hex(4)}", onboarding_status: "active",
      onboarded_at: Date.new(2026, 2, 19))

    report = client.find_or_create_monthly_report(Date.new(2026, 6, 1))

    assert_not report.is_first_report?
  end

  test "find_or_create_monthly_report falls back to report history when onboarded_at is unknown" do
    client = Client.create!(name: "Unsynced Practice #{SecureRandom.hex(4)}", onboarding_status: "active",
      onboarded_at: nil)

    first = client.find_or_create_monthly_report(Date.new(2026, 5, 1))
    assert first.is_first_report?

    second = client.find_or_create_monthly_report(Date.new(2026, 6, 1))
    assert_not second.is_first_report?
  end

  test "find_or_create_monthly_report finds the same row on a second call, without changing is_first_report" do
    client = Client.create!(name: "Idempotent Practice #{SecureRandom.hex(4)}", onboarding_status: "active",
      onboarded_at: Date.new(2026, 3, 1))

    first_call = client.find_or_create_monthly_report(Date.new(2026, 3, 1))
    second_call = client.find_or_create_monthly_report(Date.new(2026, 3, 1))

    assert_equal first_call.id, second_call.id
    assert second_call.is_first_report?
  end
end
