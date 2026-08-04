require "test_helper"

class ClientServiceLinkTest < ActiveSupport::TestCase
  test "status_label and status_dot_class across credential states" do
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    active = client.client_service_links.create!(service: "hubspot", credential_status: "active")
    assert_equal "Linked", active.status_label
    assert_equal "bg-emerald-500", active.status_dot_class

    expiring = client.client_service_links.create!(service: "yext", credential_status: "expiring_soon")
    assert_equal "Key expiring", expiring.status_label
    assert_equal "bg-amber-500", expiring.status_dot_class

    expired = client.client_service_links.create!(service: "semrush", credential_status: "expired")
    assert_equal "Auth error", expired.status_label
    assert_equal "bg-red-500", expired.status_dot_class

    invalid = client.client_service_links.create!(service: "ghl", credential_status: "invalid")
    assert_equal "Auth error", invalid.status_label
    assert_equal "bg-red-500", invalid.status_dot_class
  end

  test "status_label distinguishes unverified from not linked when credential_status is nil" do
    client = Client.create!(name: "Some Practice", onboarding_status: "active")

    unverified = client.client_service_links.create!(service: "hubspot", external_id: "company-1")
    assert_equal "Unverified", unverified.status_label
    assert_equal "bg-slate-300", unverified.status_dot_class

    not_linked = client.client_service_links.build(service: "yext")
    assert_equal "Not linked", not_linked.status_label
    assert_equal "bg-slate-300", not_linked.status_dot_class
  end
end
