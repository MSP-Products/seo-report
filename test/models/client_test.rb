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

  test "status_badge_text includes the onboarded month when present" do
    client = Client.create!(name: "Onboarded Practice", onboarding_status: "active", onboarded_at: Date.new(2026, 2, 15))

    assert_equal "Active client · onboarded Feb 2026", client.status_badge_text
  end

  test "status_badge_text omits the onboarded clause when there's no onboarded_at" do
    client = Client.create!(name: "Pending Practice", onboarding_status: "pending")

    assert_equal "Pending client", client.status_badge_text
  end

  test "latest_generated_report skips reports that were never generated" do
    client = Client.create!(name: "Practice", onboarding_status: "active")
    client.monthly_reports.create!(report_month: Date.new(2026, 7, 1))
    generated = client.monthly_reports.create!(report_month: Date.new(2026, 6, 1), generated_at: Time.current)

    assert_equal generated, client.reload.latest_generated_report
  end

  test "latest_generated_report is nil when nothing has generated" do
    client = Client.create!(name: "Practice", onboarding_status: "active")
    client.monthly_reports.create!(report_month: Date.new(2026, 6, 1))

    assert_nil client.reload.latest_generated_report
  end

  test "current_cycle_report finds the report for MonthlyReport.reporting_month" do
    travel_to Date.new(2026, 8, 15) do
      client = Client.create!(name: "Practice", onboarding_status: "active")
      current = client.monthly_reports.create!(report_month: Date.new(2026, 7, 1))
      client.monthly_reports.create!(report_month: Date.new(2026, 6, 1))

      assert_equal current, client.reload.current_cycle_report
    end
  end

  test "current_cycle_report is nil when the current cycle hasn't been attempted" do
    client = Client.create!(name: "Practice", onboarding_status: "active")

    assert_nil client.current_cycle_report
  end

  test "all_service_links returns all five services, including ones never linked" do
    client = Client.create!(name: "Practice", onboarding_status: "active")
    client.client_service_links.create!(service: "hubspot", external_id: "company-1")

    links = client.all_service_links

    assert_equal 5, links.size
    assert_equal %w[semrush yext google_analytics ghl hubspot].sort, links.map(&:service).sort
    unlinked = links.find { |l| l.service == "yext" }
    assert_not unlinked.persisted?
  end
end
