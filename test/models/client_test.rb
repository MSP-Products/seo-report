require "test_helper"

class ClientTest < ActiveSupport::TestCase
  test "city_state extracts city and state, stripping the zip" do
    client = Client.create!(name: "Woodside Dental", onboarding_status: "active",
      address: "123 Oak Street, San Francisco, CA 94102")

    assert_equal "San Francisco, CA", client.city_state
  end

  test "city_state falls back to the raw address when it can't be parsed" do
    client = Client.create!(name: "No Address Practice", onboarding_status: "active", address: "PO Box 12")

    assert_equal "PO Box 12", client.city_state
  end

  test "city_state handles a blank address" do
    client = Client.create!(name: "Blank Address Practice", onboarding_status: "active")

    assert_nil client.city_state
  end

  test "scheduler_enrolled? is true only when a ghl service link exists" do
    client = Client.create!(name: "Scheduled Practice", onboarding_status: "active")
    assert_not client.scheduler_enrolled?

    client.client_service_links.create!(service: "ghl", external_id: "location-1")
    assert client.reload.scheduler_enrolled?
  end

  test "latest_monthly_report picks the newest report_month" do
    client = Client.create!(name: "Multi Report Practice", onboarding_status: "active")
    client.monthly_reports.create!(report_month: Date.new(2026, 4, 1))
    newest = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1))
    client.monthly_reports.create!(report_month: Date.new(2026, 5, 1))

    assert_equal newest, client.reload.latest_monthly_report
  end

  test "latest_monthly_report is nil for a client with no reports" do
    client = Client.create!(name: "No Reports Practice", onboarding_status: "active")

    assert_nil client.latest_monthly_report
  end
end
